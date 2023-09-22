###############################################################################
# Utilities for Hamiltonian Dynamics
# Note on working on transformed momentum space: when the momentum follows
# 	p ~ N(0,M)
# for some positive definite M, the Hamiltonian is 
# 	H(x,p) = -log(pi(x)) + (1/2)p^T M^{-1} p
# The corresponding leapfrog update is
# 	p*(x,p)   = p  + (eps/2)grad(log pi)(x)
# 	x'(x,p*)  = x  + eps M^{-1}p*
# 	p'(x',p*) = p* + (eps/2)grad(log pi)(x')
# We work instead with the transformed momentum
#   y = M^{-1/2}p => y ~ N(0,I)
# Then, replacing p by M^{1/2}y above gives the modified Leapfrog
# 	y*(x,y)   = y  + (eps/2)M^{-1/2}grad(log pi)(x)
# 	x'(x,y*)  = x  + eps M^{-1/2}y*
# 	y'(x',y*) = y* + (eps/2)M^{-1/2}grad(log pi)(x')
# The function `conditioned_target_gradient` returns M^{-1/2}grad(log pi)(x)
###############################################################################

log_joint(target, state, momentum) = log_joint(LogDensityProblems.logdensity(target, state), momentum)
log_joint(logp, momentum) = logp - 0.5 * sqr_norm(momentum)

function conditioned_target_gradient(target_log_potential, state, estimated_target_std_dev)
    logdens, grad = LogDensityProblems.logdensity_and_gradient(target_log_potential, state) 
    grad ./= estimated_target_std_dev  # M^{-1/2}grad(log pi)(x)
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
    momentum .+= (step_size/2) .* grad

    for i in 1:n_steps 

        # full step on position
        state .+= step_size .* (momentum ./ estimated_target_std_dev) # eps M^{-1/2}y*

        logp, grad = conditioned_target_gradient(target_log_potential, state, estimated_target_std_dev)
        
        if !isfinite(log_joint(logp, momentum))
            # TODO: implement bouncing
            return false
        end

        # Neal's trick to merge successive half-steps
        if i != n_steps 
            momentum .+= step_size .* grad
        end
    end

    # last half-step
    momentum .+= (step_size/2) .* grad

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