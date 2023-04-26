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
        hamiltonian_dynamics!(
            log_potential, momentum_log_potential, state, v, explorer.step_size, explorer.n_leap_frog_until_refresh,
            replica)
        final_joint_log = log_potential(state) + momentum_log_potential(v)
        probability = min(1.0, exp(final_joint_log - init_joint_log))
        @record_if_requested!(replica.recorders, :explorer_acceptance_pr, (replica.chain, probability))
        if rand(rng) < probability 
            # accept 
        else
            hamiltonian_dynamics!(
                log_potential, momentum_log_potential, state, -v, explorer.step_size, explorer.n_leap_frog_until_refresh, 
                nothing)
        end
        randn!(rng, v)
    end
end

function flip!(v) 
    v .= -v 
end

function hamiltonian_dynamics!(
        target_log_potential, 
        momentum_log_potential, 
        x, v, step_size, n_steps, 
        replica)
    # first line of first iteration
    grad = gradient(target_log_potential, x)
    v .= v .+ (step_size/2) .* grad

    # to reduce number of gradient evaluations 
    # consider lines 2-3 of iteration n and line 1 of iteration n+1; notice lines 2 and 1 can be combined
    for i in 1:(n_steps - 1) 
        directional_before = dot(grad, v)
        x .= x .- step_size .* gradient(momentum_log_potential, v) 
        grad = gradient(target_log_potential, x) 
        directional_after = dot(grad, v) 
        second_dir_deriv = (directional_after - direction_before) / step_size
        if replica !== nothing 
            @record_if_requested!(recorders, :directional_second_derivatives, (replica.chain, second_dir_deriv))
        end
        v .= v .+ step_size .* grad
    end

    # last two lines of last iteration 
    x .= x .- step_size .* gradient(momentum_log_potential, v) 
    v .= v .+ (step_size/2) .* gradient(target_log_potential, x)
end