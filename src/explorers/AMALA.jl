

struct AMALA 
    n_refresh::Int
    initial_step_size::Float64
end

explorer_recorder_builders(explorer::AMALA) = [explorer_acceptance_pr, explorer_n_steps]

function step!(explorer::AMALA, replica, shared)

    rng = replica.rng
    target_log_potential = find_log_potential(replica, shared.tempering, shared)
    
    # TODO REMOVE THIS! ###########################
    rand!(rng, replica.state, target_log_potential)
    ###############################################

    state = replica.state
    dim = length(state)

    # TODO: get those from buffers (AVOID CLASH WITH auto_step_size's buffers)
    momentum = zeros(dim)
    target_std_deviations = ones(dim) # TODO: adapt those 
    gradient_buffer = zeros(dim)

    start_state = zeros(dim)
    start_mom = zeros(dim)

    for i in 1:explorer.n_refresh

        randn!(rng, momentum)
        init_joint_log = log_joint(target_log_potential, state, momentum)

        start_state .= state 
        start_mom .= momentum

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
        reversed_step_size = auto_step_size(
            target_log_potential, 
            target_std_deviations, 
            state, momentum, 
            replica, gradient_buffer,
            explorer.initial_step_size, lower_bound, upper_bound)

        probability = 
            if reversed_step_size == proposed_step_size 
                final_joint_log = log_joint(target_log_potential, state, momentum)
                #@show proposed_step_size
                min(1.0, exp(final_joint_log - init_joint_log)) 
            else
                #@show proposed_step_size, reversed_step_size
                0.0 
            end

        @record_if_requested!(replica.recorders, :explorer_acceptance_pr, (replica.chain, probability))

        uniform = rand(rng) 

        if uniform < probability 
            # accept: nothing to do, we work in-place
        else
            # go back 
            # TODO: add a *extra* buffer 
            state .= start_state 
            momentum .= start_mom
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

    if initial_difference < lower_bound 
        return shrink_step_size(log_joint_difference, initial_step_size, lower_bound) 
    elseif initial_difference > upper_bound 
        return grow_step_size(log_joint_difference, initial_step_size, upper_bound)
    else
        return initial_step_size
    end
end

function shrink_step_size(log_joint_difference, initial_step_size, lower_bound)
    step_size = initial_step_size
    while true 
        step_size /= 2.0 
        if log_joint_difference(step_size) > lower_bound 
            return step_size
        end
    end
end

function grow_step_size(log_joint_difference, initial_step_size, upper_bound) 
    step_size = initial_step_size 
    while true 
        step_size *= 2.0 
        if log_joint_difference(step_size) < upper_bound 
            return step_size / 2.0 # one less step, to avoid a potential cliff-like drop in acceptance
        end
    end
end

function log_joint_difference_function(
            target_log_potential, 
            target_std_deviations, 
            state, momentum, 
            replica, gradient_buffer)

    # TODO: pass those as buffers
    state_before = copy(state)
    momentum_before = copy(momentum)
    h_before = log_joint(target_log_potential, state, momentum)
    function result(step_size)
        hamiltonian_dynamics!(
            target_log_potential, target_std_deviations, 
            state, momentum, step_size, 
            1, # 1 step, i.e. a single leap frog
            replica, gradient_buffer)
        h_after = log_joint(target_log_potential, state, momentum)
        state .= state_before 
        momentum .= momentum_before
        return h_after - h_before
    end
    return result
end