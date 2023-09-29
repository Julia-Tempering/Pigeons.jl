###############################################################################
# The Pigeons implementation of AAPS is based on code by 
# Naitong Chen and Trevor Campbell (2023). Reused with their permission.
###############################################################################

""" 
$SIGNATURES 

The Apogee to Apogee Path Sampler (AAPS) by Sherlock et al. (2022). 

AAPS is a simple alternative to the No U-Turn Sampler (NUTS).
It serves a similar purpose as NUTS: the method should be robust to its choice 
of tuning parameters when compared to standard HMC.
For a given starting position and momentum (x, v), AAPS explores both forward and 
backward trajectories. The trajectories are divided into segments, with 
segments being separated by apogees (local maxima) in the energy landscape 
of -log pi(x). The tuning parameter `K` defines the number of segments to explore. 
"""
Base.@kwdef struct AAPS{T,TPrec <: Preconditioner}
    """ 
    Reference to the leapfrog step size.
    """
    step_size_ref::Base.RefValue{Float64} = Ref(1.0)

    """  
    Maximum number of segments (regions between apogees) to explore.
    """ 
    K::Int = 5 

    """ 
    See details in AutoMALA. 
    """
    default_autodiff_backend::Symbol = :ForwardDiff 

    """ 
    A strategy for building a preconditioner.
    """
    preconditioner::TPrec = MixDiagonalPreconditioner()

    """
    This gets updated after first iteration; initially `nothing` in 
    which case an identity mass matrix is used.
    """
    estimated_target_std_deviations::T = nothing
end

function adapt_explorer(explorer::AAPS, reduced_recorders, current_pt, new_tempering)
    estimated_target_std_deviations = adapt_preconditioner(explorer.preconditioner, reduced_recorders)
    # TODO: adapt step_size and K
    return AAPS(
        explorer.step_size_ref, explorer.K, explorer.default_autodiff_backend,
        explorer.preconditioner, estimated_target_std_deviations
    )
end

#=
Extract info common to all types of target and perform a step!()
=#
function _extract_commons_and_run!(explorer::AAPS, replica, shared, log_potential, state::AbstractVector)
    log_potential_autodiff = ADgradient(
        explorer.default_autodiff_backend, log_potential, replica.recorders.buffers
    )
    if shared.iterators.round == 1 && shared.iterators.scan == 1
        recorders = replica.recorders
        dim = length(state)
        temp_position = get_buffer(recorders.buffers, :aaps_fwd_position_buffer, dim)
        temp_velocity = get_buffer(recorders.buffers, :aaps_fwd_velocity_buffer, dim)
        temp_precond  = get_buffer(recorders.buffers, :aaps_diag_precond, dim)
        temp_position .= state
        randn!(replica.rng, temp_velocity)
        fill!(temp_precond, one(eltype(temp_precond)))
        old_step_size = explorer.step_size_ref[]
        println("old_step_size: $old_step_size")
        exponent = auto_step_size(
            log_potential_autodiff, temp_precond, temp_position, temp_velocity, 
            recorders, replica.chain, old_step_size, -3.0, 0.0)
        explorer.step_size_ref[] = old_step_size * (2.0 ^exponent)
        println("new step size: $(explorer.step_size_ref[])")
    end
    aaps!(
        replica.rng,
        explorer, 
        log_potential_autodiff,
        state, 
        replica.recorders, 
        replica.chain
    )
end

struct AAPSState{TV<:Vector{<:Real}}
    position::TV
    velocity::TV
    max_position::TV
end

function get_fwd_bwd_states(buffers, dim)
    fwd_state = AAPSState(
        get_buffer(buffers, :aaps_fwd_position_buffer, dim),
        get_buffer(buffers, :aaps_fwd_velocity_buffer, dim),
        get_buffer(buffers, :aaps_fwd_max_position_buffer, dim)
    )
    bwd_state = AAPSState(
        get_buffer(buffers, :aaps_bwd_position_buffer, dim),
        get_buffer(buffers, :aaps_bwd_velocity_buffer, dim),
        get_buffer(buffers, :aaps_bwd_max_position_buffer, dim)
    )
    fwd_state, bwd_state    
end

""" 
Main function for AAPS. Note that this implementation uses scheme (1) 
from the AAPS paper, which results in an acceptance probability of one.
""" 
function aaps!(
    rng::AbstractRNG,
    explorer::AAPS,
    target_log_potential,
    position::Vector,
    recorders,
    chain)

    # get buffers
    dim = length(position)
    diag_precond = get_buffer(recorders.buffers, :aaps_diag_precond, dim)
    fwd_state, bwd_state = get_fwd_bwd_states(recorders.buffers, dim)

    # initialize
    build_preconditioner!(
        diag_precond, explorer.preconditioner, rng, explorer.estimated_target_std_deviations
    )
    copyto!(fwd_state.position, position)
    copyto!(bwd_state.position, position) # start bwd at same position -> requires skipping
    randn!(rng, fwd_state.velocity)       # sample velocity ~ N(0,I) <=> sample momentum ~ N(0,diag_precond^2)
    bwd_state.velocity .= -1 .* fwd_state.velocity

    # find the initial segment by moving forward and backward
    fwd_wmax = sample_segment!(explorer, fwd_state, target_log_potential, rng, diag_precond)
    bwd_wmax = sample_segment!(explorer, bwd_state, target_log_potential, rng, diag_precond, skip_first=true) # avoids double counting initial state

    # update the Gumbel-max-trick decision
    if fwd_wmax > bwd_wmax
        wmax = fwd_wmax
        copyto!(position, fwd_state.max_position)
    else
        wmax = bwd_wmax
        copyto!(position, bwd_state.max_position)
    end

    # sample segments by continuing from the previous endpoints
    # note that K+1 segments are sampled in total, as in the original AAPS implementation
    # see https://github.com/ChrisGSherlock/AAPS/blob/c48c59d81031745cf08b6b3d3d9ad53287bf3b34/AAPS.cpp#L311
    for _ in 1:explorer.K 
        if rand(rng, Bool) # extend forward trajectory. avoids specifying in advance how many times we move forward/backward
            fwd_wmax = sample_segment!(explorer, fwd_state, target_log_potential, rng, diag_precond)
            if fwd_wmax > wmax
                wmax = fwd_wmax
                copyto!(position, fwd_state.max_position)
            end
        else
            bwd_wmax = sample_segment!(explorer, bwd_state, target_log_potential, rng, diag_precond)
            if bwd_wmax > wmax
                wmax = bwd_wmax
                copyto!(position, bwd_state.max_position)
            end
        end
    end
    # w(z,z') = exp(log_joint) => proposal always accepted
    # no need to update position, we work in place
    # TODO: accept/reject if other proposal is used
end

""" 
Sample a segment of the trajectory until an apogee is reached. 
"""
function sample_segment!(
    explorer::AAPS,
    state::AAPSState,
    target_log_potential, 
    rng::AbstractRNG, 
    diag_precond::Vector;
    skip_first::Bool = false # avoid double counting starting state. same as try0 in https://github.com/ChrisGSherlock/AAPS/blob/c48c59d81031745cf08b6b3d3d9ad53287bf3b34/AAPS.cpp#L268
    )
    step_size   = explorer.step_size_ref[]
    logp, cgrad = conditioned_target_gradient(target_log_potential, state.position, diag_precond)
    isinf(logp) && error("""
        sample_segment!: initial configuration has infinite density (logp=$logp)
    """)
    copyto!(state.max_position, state.position)  # reset max to the current position
    if skip_first
        ljoint = wmax = -typeof(logp)(Inf)
    else
        ljoint = log_joint(logp, state.velocity)
        wmax   = ljoint + rand(rng, Gumbel())
    end

    # propagate forward, checking for apogee, tracking stats, keeping track of next state using gumbel-max trick
    # note: since M is sym ⟹ p^T M^{-1} gradU = (M^{1/2}v)^T M^{-1} gradU = v^T M^{-1/2} gradU = -v^T cgrad
    # hence, p^T M^{-1} gradU > 0 ⟺ v^T cgrad < 0, and viceversa
    old_sign = sign(dot(state.velocity, cgrad))
    while true
        leap_frog!(
            target_log_potential, diag_precond, state.position, state.velocity,
            step_size)
        logp, cgrad = conditioned_target_gradient(target_log_potential, state.position, diag_precond)

        # check correctness
        (isnan(logp) || isinf(logp)) && error("""
            sample_segment!: invalid density (logp=$logp). Try decreasing the step size.
        """)

        new_sign    = sign(dot(state.velocity, cgrad))
        old_sign < 0 && new_sign > 0 && return wmax
        old_sign    = new_sign
        ljoint      = log_joint(logp, state.velocity)
        w           = ljoint + rand(rng, Gumbel())
        if w > wmax
            wmax = w
            copyto!(state.max_position, state.position)
        end
    end
end

function explorer_recorder_builders(explorer::AAPS)
    result = [explorer_acceptance_pr, explorer_n_steps, buffers]
    add_precond_recorder_if_needed!(result, explorer)
    return result
end
