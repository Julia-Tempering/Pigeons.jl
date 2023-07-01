log_joint(target, state, momentum) = log_joint(LogDensityProblems.logdensity(target, state), momentum)
log_joint(logp, momentum) = logp - 0.5 * sqr_norm(momentum)

# We use an implicit linear transformation rescaling  
# component i with 1/estimated_target_std_dev[i]
# and use an isotropic normal momentum. 
# This is equivalent to having a "mass matrix" in HMC jargon.
function conditioned_target_gradient(target_log_potential, state, estimated_target_std_dev)
    logdens, grad = LogDensityProblems.logdensity_and_gradient(target_log_potential, state) 
    grad .= grad .* estimated_target_std_dev 
    return logdens, grad
end

# See e.g., R. Neal, p.14. 
# we add tricks to make it non-allocating
function hamiltonian_dynamics!(
            target_log_potential, 
            estimated_target_std_dev, 
            state, momentum, step_size, n_steps)

    # first half-step
    _, grad = conditioned_target_gradient(target_log_potential, state, estimated_target_std_dev)
    momentum .= momentum .+ (step_size/2) .* grad

    for i in 1:n_steps 

        # full step on position
        state .= state .+ step_size .* momentum .* estimated_target_std_dev

        logp, grad = conditioned_target_gradient(target_log_potential, state, estimated_target_std_dev)
        
        if !isfinite(log_joint(logp, momentum))
            # TODO: implement bouncing
            return false
        end

        # Neal's trick to merge successive half-steps
        if i != n_steps 
            momentum .= momentum .+ step_size .* grad
        end
    end

    # last half-step
    momentum .= momentum .+ (step_size/2) .* grad

    if !isfinite(sqr_norm(momentum))
        return false
    end

    return true
end

leap_frog!(
        target_log_potential, 
        estimated_target_std_dev, 
        state, momentum, step_size) =
    hamiltonian_dynamics!(
            target_log_potential, 
            estimated_target_std_dev, 
            state, momentum, step_size, 1)