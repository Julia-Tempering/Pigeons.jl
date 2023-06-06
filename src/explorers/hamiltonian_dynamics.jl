log_joint(logp, state, momentum) = logp(state) - 0.5 * sqr_norm(momentum)

# See e.g., R. Neal, p.14. 
# we add tricks to make it non-allocating
function hamiltonian_dynamics!(
            target_log_potential, 
            estimated_target_std_dev, 
            state, momentum, step_size, n_steps, 
            gradient_buffer)

    # We use an implicit linear transformation rescaling  
    # component i with 1/estimated_target_std_dev[i]
    # and use an isotropic normal momentum. 
    function conditioned_target_gradient!()
        gradient_buffer .= gradient!!(target_log_potential, state, gradient_buffer) 
        gradient_buffer .= gradient_buffer .* estimated_target_std_dev 
    end

    # first half-step
    conditioned_target_gradient!()
    momentum .= momentum .+ (step_size/2) .* gradient_buffer

    for i in 1:n_steps 

        # full step on position
        state .= state .+ step_size .* momentum .* estimated_target_std_dev
        # TODO: bounce
        if !isfinite(log_joint(target_log_potential, state, momentum))
            return false
        end

        conditioned_target_gradient!()

        # Neal's trick to merge successive half-steps
        if i != n_steps 
            momentum .= momentum .+ step_size .* gradient_buffer
        end
    end

    # last half-step
    momentum .= momentum .+ (step_size/2) .* gradient_buffer

    if !isfinite(log_joint(target_log_potential, state, momentum))
        return false
    end

    return true
end

leap_frog!(
        target_log_potential, 
        estimated_target_std_dev, 
        state, momentum, step_size,
        gradient_buffer) =
    hamiltonian_dynamics!(
            target_log_potential, 
            estimated_target_std_dev, 
            state, momentum, step_size, 1, 
            gradient_buffer)