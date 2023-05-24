@auto struct AutoMALA 
    n_refresh::Int
    initial_step_size::Float64

    # this gets updated after first iteration; initially nothing
    target_std_deviations
end

AutoMALA(n_refresh = 10, initial_step_size = 1.0) = AutoMALA(n_refresh, initial_step_size, nothing)

function adapt_explorer(explorer::AutoMALA, reduced_recorders, current_pt, new_tempering)
    target_std_dev = 
        sqrt.(get_statistic(reduced_recorders, :singleton_variable, Variance))
    return AutoMALA(explorer.n_refresh, explorer.initial_step_size, target_std_dev)
end


function step!(explorer::AutoMALA, replica, shared)

    rng = replica.rng
    target_log_potential = find_log_potential(replica, shared.tempering, shared)
    
    # TODO: need to init? maybe let the prior do its things...?

    state = replica.state
    dim = length(state)

    momentum = get_buffer(replica.recorders.am_momentum_buffer, dim)
    target_std_deviations = get_buffer(replica.recorders.am_ones_buffer, dim)
    target_std_deviations .= 1.0
    mix = rand(rng) # random interpolation b/w unit and estimated for robustness
    if explorer.target_std_deviations !== nothing
        target_std_deviations .= mix .* target_std_deviations .+ (1.0 - mix) .* explorer.target_std_deviations
    end

    gradient_buffer = get_buffer(replica.recorders.am_gradient_buffer, dim)

    start_state = get_buffer(replica.recorders.am_state_buffer, dim)

    for i in 1:explorer.n_refresh
        start_state .= state 
        randn!(rng, momentum)
        init_joint_log = log_joint(target_log_potential, state, momentum)

        a = rand(rng)
        b = rand(rng)
        lower_bound = log(min(a, b))
        upper_bound = log(max(a, b))
        
        proposed_step_size = auto_step_size(
            target_log_potential, 
            target_std_deviations, 
            state, momentum, 
            replica, gradient_buffer,
            explorer.initial_step_size, lower_bound, upper_bound)

        # move to proposed point
        leap_frog!(
            target_log_potential, 
            target_std_deviations, 
            state, momentum, proposed_step_size,
            gradient_buffer
        )

        # flip
        momentum .*= -1.0 

        # reversibility check 
        reversed_step_size = 
            if shared.iterators.scan == 1
                # in the transient phase, the rejection rate for the 
                # reversibility check can be high, so skip it 
                # for the initial scan of each round
                proposed_step_size
            else
                auto_step_size(
                    target_log_potential, 
                    target_std_deviations, 
                    state, momentum, 
                    replica, gradient_buffer,
                    explorer.initial_step_size, lower_bound, upper_bound)
            end

        probability = 
            if reversed_step_size == proposed_step_size 
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
            # no need to reset momentum as it will get resampled next
        end
    end
end

function auto_step_size(
        target_log_potential, 
        target_std_deviations, 
        state, momentum, 
        replica, gradient_buffer,
        initial_step_size, lower_bound, upper_bound)

    @assert initial_step_size > 0
    @assert lower_bound < upper_bound
    log_joint_difference = log_joint_difference_function(
                        target_log_potential, 
                        target_std_deviations, 
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
    step_size = initial_step_size * 2.0^exponent
    @record_if_requested!(replica.recorders, :explorer_n_steps, (replica.chain, 1+n_steps)) 
    @record_if_requested!(replica.recorders, :am_exponents, (replica.chain, exponent)) 
    return step_size
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
            target_std_deviations, 
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
            target_log_potential, target_std_deviations, 
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