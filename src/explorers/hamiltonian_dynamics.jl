log_joint(target, state, momentum) = log_joint(LogDensityProblems.logdensity(target, state), momentum)
log_joint(logp, momentum) = logp - 0.5 * sqr_norm(momentum)

function test_grad_allocs() 
    
end

# See e.g., R. Neal, p.14. 
# we add tricks to make it non-allocating
function hamiltonian_dynamics!(
            target_log_potential, 
            estimated_target_std_dev, 
            state, momentum, step_size, n_steps)

    # We use an implicit linear transformation rescaling  
    # component i with 1/estimated_target_std_dev[i]
    # and use an isotropic normal momentum. 
    # This is equivalent to having a mass matrix but simplifies the code a little bit.
    function conditioned_target_logdensity_and_gradient()
        logp, gradient = LogDensityProblems.logdensity_and_gradient(target_log_potential, state) 
        gradient .= gradient .* estimated_target_std_dev 
        return logp, gradient
    end

    # first half-step
    _, gradient = conditioned_target_logdensity_and_gradient()
    momentum .= momentum .+ (step_size/2) .* gradient

    for i in 1:n_steps 

        # full step on position
        state .= state .+ step_size .* momentum .* estimated_target_std_dev

        logp, gradient = conditioned_target_logdensity_and_gradient()
        
        if !isfinite(log_joint(logp, momentum))
            # TODO: implement bouncing
            return false
        end

        # Neal's trick to merge successive half-steps
        if i != n_steps 
            momentum .= momentum .+ step_size .* gradient
        end
    end

    # last half-step
    momentum .= momentum .+ (step_size/2) .* gradient

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