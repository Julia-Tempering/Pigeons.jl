""" 
$SIGNATURES

The Metropolis-Adjusted Langevin Algorithm (MALA). 

MALA is based on an approximation to overdamped Langevin dynamics followed by a 
Metropolis-Hastings correction to ensure that we target the correct distribution.

This round-based version of MALA allows for the use of a preconditioner, 
which is updated after every PT tuning round. 
This setting can also be turned off by specifying the type of preconditioner to use.  
However, MALA will not automatically adjust the step size. 
For such functionality, use autoMALA.

As for autoMALA, the number of steps per exploration is
`base_n_refresh * ceil(Int, dim^exponent_n_refresh)`. 
"""
@kwdef struct MALA{TPrec <: Preconditioner, T}
    """
    The base number of steps (equivalently, momentum refreshments) between swaps.
    This base number gets multiplied by `ceil(Int, dim^(exponent_n_refresh))`. 
    """
    base_n_refresh::Int = 3         

    """ 
    Used to scale the increase in number of refreshments with dimensionality. 
    """
    exponent_n_refresh::Float64 = 0.35  
    
    """ 
    The default backend to use for autodiff. 
    See https://github.com/tpapp/LogDensityProblemsAD.jl#backends

    Certain targets may ignore it, e.g. if a manual differential is 
    offered or when calling an external program such as Stan.
    """
    default_autodiff_backend::Symbol = :ForwardDiff

    """
    Step size to use when approximating the Langevin dynamics.
    This is an important tuning parameter of MALA. This implementation of 
    MALA does not automatically choose the step size so the user should 
    select it carefully.
    """
    step_size::Float64 = 1.0

    """ 
    A strategy for building a preconditioner.
    """
    preconditioner::TPrec = MixDiagonalPreconditioner()

    """
    This gets updated after the first tuning round; initially it is `nothing`, in 
    which case an identity mass matrix is used for the preconditioner.
    """
    estimated_target_std_deviations::T = nothing
end

function adapt_explorer(explorer::MALA, reduced_recorders, current_pt, new_tempering)
    estimated_target_std_deviations = adapt_preconditioner(explorer.preconditioner, reduced_recorders)
    return MALA(
        explorer.base_n_refresh, explorer.exponent_n_refresh, 
        explorer.default_autodiff_backend, explorer.step_size,
        explorer.preconditioner, estimated_target_std_deviations)
end

# Extract info common to all types of target and perform a step!()
function _extract_commons_and_run!(explorer::MALA, replica, shared, log_potential, state::AbstractVector) 
    log_potential_autodiff = ADgradient(explorer.default_autodiff_backend, log_potential, replica)      
    mala!(replica.rng, explorer, log_potential_autodiff, state, replica.recorders, replica.chain)
end

# The main exploration function for MALA
function mala!(rng::AbstractRNG, explorer::MALA, target_log_potential, state::Vector, recorders, chain)
    dim = length(state)
    momentum = get_buffer(recorders.buffers, :mala_momentum_buffer, dim)
    diag_precond = get_buffer(recorders.buffers, :mala_ones_buffer, dim)
    build_preconditioner!(diag_precond, explorer.preconditioner, rng, explorer.estimated_target_std_deviations)
    start_state = get_buffer(recorders.buffers, :mala_state_buffer, dim)
    n_refresh = explorer.base_n_refresh * ceil(Int, dim^explorer.exponent_n_refresh)
    for i in 1:n_refresh
        start_state .= state 
        randn!(rng, momentum)
        init_joint_log = log_joint(target_log_potential, state, momentum)
        @assert isfinite(init_joint_log) "MALA can only be called on a configuration of positive density."
        leap_frog!(target_log_potential, diag_precond, state, momentum, explorer.step_size)
        momentum .*= -1.0 # flip momentum (involution)
        final_joint_log = log_joint(target_log_potential, state, momentum)
        probability = min(1.0, exp(final_joint_log - init_joint_log)) 
        @record_if_requested!(recorders, :explorer_acceptance_pr, (chain, probability))
        if rand(rng) < probability # accept: nothing to do, we work in-place
        else # reject: go back to start state
            state .= start_state # momentum gets resampled at next iteration anyway
        end
        @record_if_requested!(recorders, :explorer_n_steps, (chain, 1)) # MALA always only does one leapfrog
    end
end

function explorer_recorder_builders(explorer::MALA)
    result = [explorer_acceptance_pr, explorer_n_steps]
    gradient_based_sampler_recorders!(result, explorer)
    return result
end