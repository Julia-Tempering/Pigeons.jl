""" 
$SIGNATURES

The Metropolis-Adjusted Langevin Algorithm with 
automatic step size selection. 

Briefly, at each iteration, the step size is exponentially shrunk or 
grown until the acceptance rate is in a reasonable range. A reversibility 
check ensures that the move is reversible with respect to the target. 
The process is started at `step_size`, which at the end of each 
round is set to the average exponent used across all chains. 

The number of steps per exploration is set to 
`base_n_refresh * ceil(Int, dim^exponent_n_refresh)`. 

At each round, an empirical diagonal marginal standard deviation matrix is estimated. At each step, 
a random interpolation between the identity and the estimated standard deviation is used to 
condition the problem. 

In normal circumstance, there should not be a need for tuning, 
however the following optional keyword parameters are available:
$FIELDS
"""
@kwdef struct AutoMALA{T}
    """
    The base number of steps (equivalently, momentum refreshments) between swaps.
    This base number gets multiplied by `ceil(Int, dim^(exponent_n_refresh))`. 
    """
    base_n_refresh::Int = 3         

    """ 
    Used to scale the increase in number of refreshment with dimensionality. 
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
    Starting point for the automatic step size algorithm. 
    Gets updated automatically between each round. 
    """
    step_size::Float64 = 1.0

    """ 
    If a diagonal pre-conditioning should be learned.
    """
    adapt_pre_conditioning::Bool = true

    """
    This gets updated after first iteration; initially `nothing` in 
    which case a diagonal mass matrix is used.
    """
    estimated_target_std_deviations::T = nothing

    # TODO: add option(s) for transformations? For now, doing it only for Turing
end

function adapt_explorer(explorer::AutoMALA, reduced_recorders, current_pt, new_tempering)
    estimated_target_std_dev = 
        explorer.adapt_pre_conditioning ? 
            sqrt.(get_transformed_statistic(reduced_recorders, :singleton_variable, Variance)) :
            nothing
    # use the mean across chains of the mean shrink/grow factor to compute a new baseline stepsize
    updated_step_size = explorer.step_size * mean(mean.(values(value(reduced_recorders.am_factors))))
    return AutoMALA(
                explorer.base_n_refresh, explorer.exponent_n_refresh, explorer.default_autodiff_backend, 
                updated_step_size,
                explorer.adapt_pre_conditioning, 
                estimated_target_std_dev)
end

function step!(explorer::AutoMALA, replica, shared)
    step!(explorer, replica, shared, replica.state)
end

### Dispatch on state for the behaviours for the different targets ###

    step!(explorer::AutoMALA, replica, shared, state::StanState) = 
        step!(explorer, replica, shared, state.unconstrained_parameters)


    function step!(explorer::AutoMALA, replica, shared, state::AbstractVector)
        log_potential = find_log_potential(replica, shared.tempering, shared)
        _extract_commons_and_run_auto_mala!(explorer, replica, shared, log_potential, state)
    end

    function step!(explorer::AutoMALA, replica, shared, vi::DynamicPPL.TypedVarInfo)
        log_potential = find_log_potential(replica, shared.tempering, shared)
        state = DynamicPPL.getall(vi)
        _extract_commons_and_run_auto_mala!(explorer, replica, shared, log_potential, state)
        DynamicPPL.setall!(replica.state, state)
    end

#=
Extract info common to all types of target and perform a step!()
=#
function _extract_commons_and_run_auto_mala!(explorer::AutoMALA, replica, shared, log_potential, state::AbstractVector) 
    
    log_potential_autodiff = ADgradient(explorer.default_autodiff_backend, log_potential, replica.recorders.buffers)      
    is_first_scan_of_round = shared.iterators.scan == 1

    auto_mala!(
        replica.rng,
        explorer, 
        log_potential_autodiff,
        state, 
        replica.recorders, 
        replica.chain,
        # In the transient phase, the rejection rate for the 
        # reversibility check can be high, so skip accept-rejct 
        # for the initial scan of each round.
        # We only do this on the first scan of each round.
        # Since the number of iterations per round increases, 
        # the fraction of time we do this decreases to zero.
        !is_first_scan_of_round
    )
end

function auto_mala!(
        rng::AbstractRNG,
        explorer::AutoMALA, 
        target_log_potential, 
        state::Vector, 
        recorders, 
        chain,
        use_mh_accept_reject)

    dim = length(state)

    momentum = get_buffer(recorders.buffers, :am_momentum_buffer, dim)
    estimated_target_std_dev = get_buffer(recorders.buffers, :am_ones_buffer, dim)
    estimated_target_std_dev .= 1.0
    mix = rand(rng) # random interpolation b/w unit and estimated for robustness
    if !isnothing(explorer.estimated_target_std_deviations)
        estimated_target_std_dev .= mix .* estimated_target_std_dev .+ (1.0 - mix) .* explorer.estimated_target_std_deviations
    end
    
    start_state = get_buffer(recorders.buffers, :am_state_buffer, dim)

    n_refresh = explorer.base_n_refresh * ceil(Int, dim^explorer.exponent_n_refresh)
    for i in 1:n_refresh
        start_state .= state 
        randn!(rng, momentum)
        init_joint_log = log_joint(target_log_potential, state, momentum)
        @assert isfinite(init_joint_log) "AutoMALA can only be called on a configuration of positive density."

        # Randomly pick a "reasonable" range of MH accept probabilities (in log-scale)
        # We do this to preserve the same irreducibility structure on the augmented space (x, v) 
        # as standard MALA.
        a = rand(rng)
        b = rand(rng)
        lower_bound = log(min(a, b))
        upper_bound = log(max(a, b))
        
        proposed_exponent = 
            auto_step_size(
                target_log_potential, 
                estimated_target_std_dev, 
                state, momentum, 
                recorders, chain,
                explorer.step_size, lower_bound, upper_bound)
        proposed_step_size = explorer.step_size * 2.0^proposed_exponent

        # move to proposed point
        leap_frog!(
            target_log_potential, 
            estimated_target_std_dev, 
            state, momentum, proposed_step_size
        )

        if use_mh_accept_reject 
            # flip
            momentum .*= -1.0 
            reversed_exponent = 
                auto_step_size(
                    target_log_potential, 
                    estimated_target_std_dev, 
                    state, momentum, 
                    recorders, chain,
                    explorer.step_size, lower_bound, upper_bound)
            probability = 
                if reversed_exponent == proposed_exponent 
                    final_joint_log = log_joint(target_log_potential, state, momentum)
                    min(1.0, exp(final_joint_log - init_joint_log)) 
                else
                    0.0 
                end
            @record_if_requested!(recorders, :explorer_acceptance_pr, (chain, probability))
            if rand(rng) < probability 
                # accept: nothing to do, we work in-place
            else
                # reject: go back to start state
                state .= start_state 
                # no need to reset momentum as it will get resampled at beginning of the loop
            end
        end
    end
end

function auto_step_size(
        target_log_potential, 
        estimated_target_std_dev, 
        state, momentum, 
        recorders, chain, 
        step_size, lower_bound, upper_bound)

    @assert step_size > 0
    @assert lower_bound < upper_bound
    
    log_joint_difference = 
        log_joint_difference_function(
            target_log_potential, 
            estimated_target_std_dev, 
            state, momentum, 
            recorders)
    initial_difference = log_joint_difference(step_size) 

    n_steps, exponent = 
        if !isfinite(initial_difference) || initial_difference < lower_bound 
            shrink_step_size(log_joint_difference, step_size, lower_bound) 
        elseif initial_difference > upper_bound 
            grow_step_size(log_joint_difference, step_size, upper_bound)
        else
            0, 0
        end
    
    @record_if_requested!(recorders, :explorer_n_steps, (chain, 1+n_steps)) 
    @record_if_requested!(recorders, :am_factors, (chain, 2.0^exponent)) 
    return exponent
end

function grow_step_size(log_joint_difference, step_size, upper_bound) 
    n = 1
    while true
        step_size *= 2.0 
        diff = log_joint_difference(step_size)
        if !isfinite(diff) || diff < upper_bound
            return n, n - 1 # one less step, to avoid a potential cliff-like drop in acceptance
        end
        n += 1
    end
end

function shrink_step_size(log_joint_difference, step_size, lower_bound)
    n = 1
    while true
        step_size /= 2.0 
        diff = log_joint_difference(step_size) 
        #= 
        Note that shrink is a bit different than grow. 
        We do not assume here that the diff is necessarily 
        finite when we start this loop: indeed, when the step 
        size is too big, we may have to shrink several times 
        until we get to a scale giving a finite evaluation. 
        =#
        if step_size == 0.0 
            error("Could not find a positive step size with diff > $lower_bound")
        end
        if diff > lower_bound 
            return n, -n
        end
        n += 1
    end
end

function log_joint_difference_function(
            target_log_potential, 
            estimated_target_std_dev, 
            state, momentum, 
            recorders)

    dim = length(state)

    state_before = get_buffer(recorders.buffers, :am_ljdf_state_before_buffer, dim)
    state_before .= state 

    momentum_before = get_buffer(recorders.buffers, :am_ljdf_momentum_before_buffer, dim)
    momentum_before .= momentum

    h_before = log_joint(target_log_potential, state, momentum)
    function result(step_size)
        leap_frog!(
            target_log_potential, estimated_target_std_dev, 
            state, momentum, step_size)
        h_after = log_joint(target_log_potential, state, momentum)
        state .= state_before 
        momentum .= momentum_before
        return h_after - h_before
    end
    return result
end

am_factors() = GroupBy(Int, Mean())

function explorer_recorder_builders(explorer::AutoMALA)
    result = [
        explorer_acceptance_pr, 
        explorer_n_steps,
        am_factors,
        buffers
    ]
    if explorer.adapt_pre_conditioning 
        push!(result, _transformed_online) # for mass matrix adaptation
    end
    return result
end