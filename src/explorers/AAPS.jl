###############################################################################
# The Pigeons implementation of AAPS is based on code by 
# Naitong Chen and Trevor Campbell (2023). Reused with their permission.
# Note:
# y(x) := M^{-1/2}x => x(y) = M^{1/2}y
# x ~ p_x => p_y(y) = p_x(M^{1/2}y) |detM|^{1/2} propto p_x(M^{1/2}y) 
# => grad{log p_y}(y) = M^{1/2} grad(log p_x)(M^{1/2}y) 
# for p ~ N(0,M), the leapfrog is
#   p*(x,p)   = p + (eps/2)grad(x)
#   x'(x,p*)  = x + epsM^{-1}p*
#   p'(x',p*) = p* + (eps/2)grad(x')
# if y = M^{-1/2}p => y ~ N(0,I) and p = M^{1/2}y.
#   y*(x,y)   = M^{1/2}y + (eps/2)grad(x)
#   x'(x,y*)  = x + epsM^{-1}y*
#   y'(x',y*) = y* + (eps/2)grad(x')
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
    Leapfrog step size.
    """
    ϵ::Float64 = 1.0

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
    # TODO: adapt ϵ and K
    return AAPS(
        explorer.ϵ, explorer.K, explorer.default_autodiff_backend,
        explorer.preconditioner, estimated_target_std_deviations
    )
end

#=
Extract info common to all types of target and perform a step!()
=#
function _extract_commons_and_run_aaps!(explorer::AAPS, replica, shared, log_potential, state::AbstractVector)
    log_potential_autodiff = ADgradient(
        explorer.default_autodiff_backend, log_potential, replica.recorders.buffers
    )      
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
    log_joint::TV
    wmax::TV
end

function get_fwd_bwd_states(buffers, dim)
    fwd_state = AAPSState(
        get_buffer(buffers, :aaps_fwd_position_buffer, dim),
        get_buffer(buffers, :aaps_fwd_velocity_buffer, dim),
        get_buffer(buffers, :aaps_fwd_max_position_buffer, dim),
        get_buffer(buffers, :aaps_fwd_log_joint_buffer, 1),
        get_buffer(buffers, :aaps_fwd_wmax_buffer, 1),
    )
    bwd_state = AAPSState(
        get_buffer(buffers, :aaps_bwd_position_buffer, dim),
        get_buffer(buffers, :aaps_bwd_velocity_buffer, dim),
        get_buffer(buffers, :aaps_bwd_max_position_buffer, dim),
        get_buffer(buffers, :aaps_bwd_log_joint_buffer, 1),
        get_buffer(buffers, :aaps_bwd_wmax_buffer, 1),
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
    diag_precond = get_buffer(recorders.buffers, :am_ones_buffer, dim)
    fwd_state, bwd_state = get_fwd_bwd_states(recorders.buffers, dim)

    # initialize
    build_preconditioner!(
        diag_precond, explorer.preconditioner, rng, explorer.estimated_target_std_deviations
    )
    copyto!(fwd_state.position, position)
    copyto!(bwd_state.position, position)
    randn!(rng, fwd_state.velocity) # sample velocity ~ N(0,I) <=> sample momentum ~ N(0,diag_precond^2)
    bwd_state.velocity .= -1 .* fwd_state.velocity
    init_log_joint = log_joint(target_log_potential, fwd_state.position, fwd_state.velocity)
    fwd_state.log_joint[1] = bwd_state.log_joint[1] = init_log_joint

    # find the initial segment by moving forward and backward
    sample_segment!(explorer, fwd_state, target_log_potential, rng, diag_precond)
    sample_segment!(explorer, bwd_state, target_log_potential, rng, diag_precond)

    # update the Gumbel-max-trick decision
    if fwd_state.wmax > bwd_state.wmax
        wmax = fwd_state.wmax
        copyto!(position, fwd_state.position)
    else
        wmax = bwd_state.wmax
        copyto!(position, bwd_state.position)
    end


    # sample segments by continuing from the previous endpoints
    # note that K+1 segments are sampled in total, as in the original AAPS implementation
    # see https://github.com/ChrisGSherlock/AAPS/blob/c48c59d81031745cf08b6b3d3d9ad53287bf3b34/AAPS.cpp#L311
    for _ in 1:explorer.K
        if rand(rng, Bool)
            # extend the forward trajectory
            # (avoids specifying in advance how many times we move forward/backward)
            state = θfwd
            rtemp = rfwd
            θfwd, rfwd, Wmax_2, θmax_2, rmax_2 = 
                sample_segment(explorer, state, rtemp, init_log_joint, target_log_potential, rng, diag_precond)
        else  
            # extend the backward trajectory
            state = θbwd
            rtemp = rbwd
            θbwd, rbwd, Wmax_2, θmax_2, rmax_2 = 
                sample_segment(explorer, state, rtemp, init_log_joint, target_log_potential, rng, diag_precond)
        end
        if Wmax_2 > Wmax
            θmax = θmax_2
            rmax = rmax_2
            Wmax = Wmax_2
        end
    end  
    # set the final state and update step size
    state = copy(θmax)
    r = copy(rmax)
end

""" 
Sample a segment of the trajectory until an apogee is reached. 
"""
function sample_segment(
    explorer::AAPS,
    state::AAPSState,
    target_log_potential, 
    rng::AbstractRNG, 
    diag_precond::Vector)
    θ0    = copy(state)
    rtemp = copy(r)
    θmax  = copy(state)
    rmax  = copy(r)
    _, g0 = LogDensityProblems.logdensity_and_gradient(target_log_potential, state) 
    lp    = init_log_joint
    Wmax  = lp + rand(rng, Gumbel()) # todo: why do we repeat this calculation?
  
    # propagate forward, checking for apogee, tracking stats, keeping track of next state using gumbel-max trick
    s0 = sign(dot(rtemp, -g0))
    while true
        leap_frog!(
            target_log_potential, 
            diag_precond, 
            state, rtemp, explorer.ϵ 
        )
        _, g0 = LogDensityProblems.logdensity_and_gradient(target_log_potential, state) 
        s = sign(dot(rtemp, -g0))
        if s != s0
            break # TODO: This seems to define a segment as a place where the sign changes 
            # i.e., either a local minimum or maximum. 
            # However, the "apogee" in AAPS clearly indicates that we should only 
            # define new segments when we reach a maximum.
        end
        lp = log_joint(target_log_potential, state, rtemp)
        W = lp + rand(rng, Gumbel())
        if W > Wmax
            Wmax = W
            θmax = state
            rmax = rtemp
        end
    end
    θfwd, rfwd = copy(state), copy(rtemp)
    state = θ0
    
    return θfwd, rfwd, Wmax, θmax, rmax
end


function explorer_recorder_builders(explorer::AAPS)
    result = [explorer_acceptance_pr, explorer_n_steps, buffers]
    add_precond_recorder_if_needed!(results, explorer)
    return result
end
