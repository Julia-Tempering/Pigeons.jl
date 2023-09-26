###############################################################################
# Utilities for Hamiltonian Dynamics
#
# In the following, diag_precond = M^{1/2}, where M is the mass matrix
# following "Neal, MCMC using Hamiltonian.." the mass matrix is the covariance matrix of the momentum auxiliary variable
# Instead fo the momentum, we actually store M^{-1/2} p, which we call transformed momentum or following physics terminology, velocity
# TODO: the source should be search and replaced momentum -> velocity 
#
# Based on the same Neal paper, we try to approximate M ≈ inverse of the covariance of the target

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

function conditioned_target_gradient(target_log_potential, state, diag_precond)
    logdens, grad = LogDensityProblems.logdensity_and_gradient(target_log_potential, state) 
    grad ./= diag_precond  # M^{-1/2}grad(log pi)(x)
    return logdens, grad
end

# See e.g., R. Neal, p.14. 
# we add tricks to make it non-allocating
function hamiltonian_dynamics!(
            target_log_potential, 
            diag_precond, 
            state, momentum, step_size, n_steps)

    # first half-step
    logp, grad = conditioned_target_gradient(target_log_potential, state, diag_precond)
    initial_log_joint = current_log_joint = log_joint(logp, momentum)
    momentum .+= (step_size/2) .* grad

    for i in 1:n_steps 

        # full step on position
        state .+= step_size .* (momentum ./ diag_precond) # eps M^{-1/2}y*

        logp, grad = conditioned_target_gradient(target_log_potential, state, diag_precond)
        current_log_joint = log_joint(logp, momentum)

        if !isfinite(current_log_joint)
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
        diag_precond, 
        state, momentum, step_size) =
    hamiltonian_dynamics!(
            target_log_potential, 
            diag_precond, 
            state, momentum, step_size, 1)