

struct AMALA 

end

function step!(explorer::AMALA, replica, shared)

    rng = replica.rng
    log_potential = find_log_potential(replica, shared.tempering, shared)
    
    state = replica.state
    dim = length(state)

    momentum = get_buffer(replica.recorders.momentum_buffer, dim) 
    ones_buffer = get_buffer(replica.recorders.ones_buffer, dim)
    gradient_buffer = get_buffer(replica.recorders.gradient_buffer, dim)
    state_start = get_buffer(replica.recorders.state_buffer, dim)
    state_start .= state

    proposed_step_size = auto_step_size(
        target_log_potential, 
        target_std_deviations, 
        state, momentum, 
        replica, gradient_buffer,
        initial_step_size, lower_bound, upper_bound)

    leap_frog!(
        target_log_potential, 
        target_std_deviations, 
        state, momentum, proposed_step_size,
        gradient_buffer
    )

    

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