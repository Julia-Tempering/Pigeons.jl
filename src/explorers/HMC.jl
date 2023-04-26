struct HMC
    step_size::Float64 
    n_leap_frog_until_refresh::Int
    n_refresh::Int
end

adapt_explorer(explorer::HMC, reduced_recorders, shared) = explorer 
explorer_recorder_builders(::HMC) = [explorer_acceptance_pr] 
step!(explorer::HMC, replica, shared) = step!(explorer, replica, replica.rng, find_log_potential(replica, shared))

function step!(explorer::HMC, replica, rng, log_potential) 
    state = replica.state
    dim = length(state)

    # TODO: change this into adaptive matrix
    momentum_log_potential = ScaledPrecisionNormalLogPotential(1.0, dim)

    # init v
    v = randn(rng, dim)

    for i in 1:explorer.n_refresh
        init_joint_log  = log_potential(state) + momentum_log_potential(v)
        hamiltonian_dynamics!(log_potential, momentum_log_potential, state, v, explorer.step_size, explorer.n_leap_frog_until_refresh)
        final_joint_log = log_potential(state) + momentum_log_potential(v)
        probability = min(1.0, exp(final_joint_log - init_joint_log))
        @record_if_requested!(replica.recorders, :explorer_acceptance_pr, (replica.chain, probability))
        if rand(rng) < probability 
            # accept 
        else
            hamiltonian_dynamics!(log_potential, momentum_log_potential, state, -v, explorer.step_size, explorer.n_leap_frog_until_refresh)
        end
        randn!(rng, v)
    end
end

function flip!(v) 
    v .= -v 
end

function hamiltonian_dynamics!(target_log_potential, momentum_log_potential, x, v, step_size, n_steps)
    # first line of first iteration
    v .= v .+ (step_size/2) .* gradient(target_log_potential, x)

    # to reduce number of gradient evaluations 
    # consider lines 2-3 of iteration n and line 1 of iteration n+1; notice lines 2 and 1 can be combined
    for i in 1:(n_steps - 1) 
        x .= x .- step_size .* gradient(momentum_log_potential, v) 
        v .= v .+ step_size .* gradient(target_log_potential, x)
    end

    # last two lines of last iteration 
    x .= x .- step_size .* gradient(momentum_log_potential, v) 
    v .= v .+ (step_size/2) .* gradient(target_log_potential, x)
end