@auto struct AutoMALA 
    base_n_refresh::Int           # gets multiplied by ceil(Int, dim^(exponent_n_refresh))
    exponent_n_refresh::Float64   # defaults to 0.5, a bit more than 1/3 for added robustness
    initial_step_size::Float64    # starting point for the automatic step size algorithm

    # this gets updated after first iteration; initially nothing
    estimated_target_std_deviations
end

""" 
$SIGNATURES

The Metropolis-Adjusted Langevin Algorithm with 
automatic step size selection. 

Briefly, at each iteration, the step size is exponentially shrunk or 
grown until the acceptance rate is in a reasonable range. A reversibility 
check ensures that the move is reversible with respect to the target. 
The process is started at `initial_step_size`, which at the end of each 
round is set to the average exponent used across all chains. 

The number of steps per exploration is set to 
`base_n_refresh * ceil(Int, dim^exponent_n_refresh)`. 

At each round, an empirical diagonal marginal standard deviation matrix is estimated. At each step, 
a random interpolation between the identity and the estimated standard deviation is used to 
condition the problem. 
"""
AutoMALA(base_n_refresh = 10, exponent_n_refresh = 0.5, initial_step_size = 1.0) = AutoMALA(base_n_refresh, exponent_n_refresh, initial_step_size, nothing)

function adapt_explorer(explorer::AutoMALA, reduced_recorders, current_pt, new_tempering)
    estimated_target_std_dev = 
        sqrt.(get_statistic(reduced_recorders, :singleton_variable, Variance))
    # use the mean across chains of the mean shrink/grow exponent to compute a new baseline stepsize
    updated_initial_step_size = explorer.initial_step_size * 2.0^mean(mean.(values(value(reduced_recorders.am_exponents))))
    return AutoMALA(
                explorer.base_n_refresh, explorer.exponent_n_refresh,
                updated_initial_step_size,
                estimated_target_std_dev)
end

function step!(explorer::AutoMALA, replica, shared)

    rng = replica.rng
    target_log_potential = find_log_potential(replica, shared.tempering, shared)
    
    state = replica.state
    dim = length(state)

    momentum = get_buffer(replica.recorders.am_momentum_buffer, dim)
    estimated_target_std_dev = get_buffer(replica.recorders.am_ones_buffer, dim)
    estimated_target_std_dev .= 1.0
    mix = rand(rng) # random interpolation b/w unit and estimated for robustness
    if !isnothing(explorer.estimated_target_std_deviations)
        estimated_target_std_dev .= mix .* estimated_target_std_dev .+ (1.0 - mix) .* explorer.estimated_target_std_deviations
    end
    
    gradient_buffer = get_buffer(replica.recorders.am_gradient_buffer, dim)
    start_state = get_buffer(replica.recorders.am_state_buffer, dim)

    n_refresh = explorer.base_n_refresh * ceil(Int, dim^explorer.exponent_n_refresh)
    for i in 1:n_refresh
        start_state .= state 
        randn!(rng, momentum)
        init_joint_log = log_joint(target_log_potential, state, momentum)

        a = rand(rng)
        b = rand(rng)
        lower_bound = log(min(a, b))
        upper_bound = log(max(a, b))
        
        proposed_exponent = 
            auto_step_size(
                target_log_potential, 
                estimated_target_std_dev, 
                state, momentum, 
                replica, gradient_buffer,
                explorer.initial_step_size, lower_bound, upper_bound)
        proposed_step_size = explorer.initial_step_size * 2.0^proposed_exponent

        # move to proposed point
        leap_frog!(
            target_log_potential, 
            estimated_target_std_dev, 
            state, momentum, proposed_step_size,
            gradient_buffer
        )

        is_first_scan_of_round = shared.iterators.scan == 1
        if is_first_scan_of_round 
            # in the transient phase, the rejection rate for the 
            # reversibility check can be high, so skip accept-rejct 
            # for the initial scan of each round
        else
            # flip
            momentum .*= -1.0 
            reversed_exponent = 
                auto_step_size(
                    target_log_potential, 
                    estimated_target_std_dev, 
                    state, momentum, 
                    replica, gradient_buffer,
                    explorer.initial_step_size, lower_bound, upper_bound)
            probability = 
                if reversed_exponent == proposed_exponent 
                    final_joint_log = log_joint(target_log_potential, state, momentum)
                    min(1.0, exp(final_joint_log - init_joint_log)) 
                else
                    0.0 
                end
            @record_if_requested!(replica.recorders, :explorer_acceptance_pr, (replica.chain, probability))
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
        replica, gradient_buffer,
        initial_step_size, lower_bound, upper_bound)

    @assert initial_step_size > 0
    @assert lower_bound < upper_bound
    log_joint_difference = 
        log_joint_difference_function(
            target_log_potential, 
            estimated_target_std_dev, 
            state, momentum, 
            replica, gradient_buffer)

    initial_difference = log_joint_difference(initial_step_size) 

    n_steps, exponent = 
        if initial_difference < lower_bound 
            shrink_step_size(log_joint_difference, initial_step_size, lower_bound) 
        elseif initial_difference > upper_bound 
            grow_step_size(log_joint_difference, initial_step_size, upper_bound)
        else
            0, 0
        end
    
    @record_if_requested!(replica.recorders, :explorer_n_steps, (replica.chain, 1+n_steps)) 
    @record_if_requested!(replica.recorders, :am_exponents, (replica.chain, exponent)) 
    return exponent
end

function shrink_step_size(log_joint_difference, initial_step_size, lower_bound)
    step_size = initial_step_size
    n = 1
    while true 
        step_size /= 2.0 
        if log_joint_difference(step_size) > lower_bound 
            return n, -n
        end
        n += 1
    end
end

function grow_step_size(log_joint_difference, initial_step_size, upper_bound) 
    step_size = initial_step_size 
    n = 1
    while true 
        step_size *= 2.0 
        if log_joint_difference(step_size) < upper_bound 
            return n, n - 1 # one less step, to avoid a potential cliff-like drop in acceptance
        end
        n += 1
    end
end

function log_joint_difference_function(
            target_log_potential, 
            estimated_target_std_dev, 
            state, momentum, 
            replica, gradient_buffer)

    dim = length(state)

    state_before = get_buffer(replica.recorders.am_ljdf_state_before_buffer, dim)
    state_before .= state 

    momentum_before = get_buffer(replica.recorders.am_ljdf_momentum_before_buffer, dim)
    momentum_before .= momentum

    h_before = log_joint(target_log_potential, state, momentum)
    function result(step_size)
        leap_frog!(
            target_log_potential, estimated_target_std_dev, 
            state, momentum, step_size, 
            gradient_buffer)
        h_after = log_joint(target_log_potential, state, momentum)
        state .= state_before 
        momentum .= momentum_before
        return h_after - h_before
    end
    return result
end

am_ljdf_state_before_buffer() = Augmentation{Vector{Float64}}() 
am_ljdf_momentum_before_buffer() = Augmentation{Vector{Float64}}()

am_momentum_buffer() = Augmentation{Vector{Float64}}() 
am_state_buffer() = Augmentation{Vector{Float64}}()
am_gradient_buffer() = Augmentation{Vector{Float64}}()
am_ones_buffer() = Augmentation{Vector{Float64}}()

am_exponents() = GroupBy(Int, Mean())

explorer_recorder_builders(explorer::AutoMALA) = [
    target_online, # for mass matrix adaptation
    explorer_acceptance_pr, 
    explorer_n_steps,
    am_exponents,
    am_ljdf_state_before_buffer,
    am_ljdf_momentum_before_buffer,
    am_momentum_buffer,
    am_state_buffer,
    am_gradient_buffer,
    am_ones_buffer
]