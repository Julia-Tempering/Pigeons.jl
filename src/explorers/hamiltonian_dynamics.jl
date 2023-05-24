# See e.g., R. Neal, p.14. 
# we add a cheap curvature estimator for adaptation and tricks to make it 
# non-allocating
function hamiltonian_dynamics!(
            target_log_potential, 
            target_std_deviations, 
            state, momentum, step_size, n_steps, 
            replica, gradient_buffer)

    # We use an implicit linear transformation rescaling  
    # component i with 1/target_std_deviations[i]
    # and use an isotropic normal momentum. 
    # We use this instead of the equivalent momentum with a mass matrix
    # formulation so that we can estimate the residual curvature induced 
    # by correlations not captured by matching the componentwise 
    # moments. 
    function conditioned_target_gradient!()
        gradient_buffer .= gradient!!(target_log_potential, state, gradient_buffer) 
        gradient_buffer .= gradient_buffer .* target_std_deviations 
    end

    # keep previous grad to get directional curvature statistics
    conditioned_target_gradient!()

    # # first half-step
    momentum .= momentum .+ (step_size/2) .* gradient_buffer

    for i in 1:n_steps 
        # more setup for directional curvature stats
        directional_before = -dot(gradient_buffer, momentum)
        # full step on position
        state .= state .+ step_size .* momentum .* target_std_deviations
        # TODO: bounce
        if !isfinite(log_joint(target_log_potential, state, momentum))
            return false
        end

        # compute and record directional curvature data point
        conditioned_target_gradient!()
        directional_after = -dot(gradient_buffer, momentum) 

        second_dir_deriv = abs(directional_after - directional_before) / step_size / sqr_norm(momentum)
        if replica !== nothing && 
            isfinite(second_dir_deriv) # in case e.g. norm of momentum is very small
            @record_if_requested!(replica.recorders, :directional_second_derivatives, (replica.chain, second_dir_deriv))
        end

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
        target_std_deviations, 
        state, momentum, step_size,
        gradient_buffer) =
    # TODO: implement directly if settle here 
    hamiltonian_dynamics!(
            target_log_potential, 
            target_std_deviations, 
            state, momentum, step_size, 1, 
            nothing, gradient_buffer)