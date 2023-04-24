struct HMC

end

# """
# $SIGNATURES
# """
# @provides explorer create_explorer(target::TuringLogPotential, inputs) = HMC() 

adapt_explorer(explorer::HMC, _, _) = explorer 
explorer_recorder_builders(::HMC) = [] 

step!(explorer::HMC, replica, shared) = step!(explorer, replica.state, replica.rng, find_log_potential(replica, shared))

function step!(explorer::HMC, state, rng, log_potential)
    # instantiate velocity

    # follow dyns 

    # accept-reject

    # roll back if rejected
end

function flip!(v) 
    v .= -v 
end

struct FastGradientGaussian 

end

function hamiltonian_dynamics!(target_log_potential, momentum_log_potential, x, v, step_size, traj_length)
    # first line of first iteration
    v .= v .+ (step_size/2) .* gradient(target_log_potential, x)

    # to reduce number of gradient evaluations 
    # combine line 2-3 of iteration n with line 1 of iteration n+1 
    for i in 1:(traj_length - 1) 
        x .= x .- step_size .* gradient(momentum_log_potential, v) 
        v .= v .+ step_size .* gradient(target_log_potential, x)
    end

    # last two lines of last iteration 
    x .= x .- step_size .* gradient(momentum_log_potential, v) 
    v .= v .+ (step_size/2) .* gradient(target_log_potential, x)
    return traj_length
end