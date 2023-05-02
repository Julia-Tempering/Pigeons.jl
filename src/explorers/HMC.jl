@concrete struct HMC
    # public
    base_step_size::Float64 
    trajectory_length::Float64
    n_refresh::Int

    # private
    adapted_momentum
    interpolated_curvatures
    step_size_scalings
end

HMC() = HMC(0.01, 1.0, 3, nothing, nothing, nothing)
adapted(old::HMC, adapted_momentum, interpolated_curvatures, step_size_scalings) = 
    HMC(
        old.base_step_size, 
        old.trajectory_length,
        old.n_refresh,
        adapted_momentum, interpolated_curvatures, step_size_scalings)

function adapt_explorer(explorer::HMC, reduced_recorders, current_pt, new_tempering)
    target_variances = get_statistic(reduced_recorders, :singleton_variable, Variance) 
    
    # Build an interpolation from the worst-curvature estimates
    betas = current_pt.shared.tempering.schedule.grids
    curvature_estimates = value(reduced_recorders.directional_second_derivatives)
    ys = zeros(length(betas))
    for i in eachindex(betas) 
        j = i == 1 ? 2 : i # TODO: will need to change for 2 refs 
        ys[i] = maximum(curvature_estimates[j])
    end
    interpolated = BSplineKit.interpolate(betas, ys, BSplineOrder(4))

    # heuristic based on R. Neal 2012, 'MCMC using Hamiltonian dynamics' just below equation (4.7)
    step_size_scalings = 1.0 ./ sqrt.(interpolated.(new_tempering.schedule.grids))
    
    return adapted(
            explorer, 
            # set the momentum precisions to the target variances: see e.g. R. Neal 2012, p.22
            HetPrecisionNormalLogPotential(target_variances), # not a bug, momentum_variance = 1/estimated_target_variance
            interpolated,
            step_size_scalings
        )
end

explorer_recorder_builders(::HMC) = [explorer_acceptance_pr, target_online, directional_second_derivatives] 

struct HetPrecisionNormalLogPotential 
    precisions::Vector{Float64}
end
HetPrecisionNormalLogPotential(dim::Int) = HetPrecisionNormalLogPotential(ones(dim))

function gradient(log_potential::HetPrecisionNormalLogPotential, x) 
    len = length(x)
    @assert len == length(log_potential.precisions) 
    result = zeros(len)
    for i in 1:len 
        result[i] = -log_potential.precisions[i] * x[i] 
    end
    return result
end

function (log_potential::HetPrecisionNormalLogPotential)(x) 
    len = length(x)
    @assert len == length(log_potential.precisions)
    sum = 0.0
    for i in 1:len 
        sum += log_potential.precisions[i] * x[i]
    end
    -0.5 * sum
end

function step!(explorer::HMC, replica, shared)   
    rng = replica.rng
    log_potential = find_log_potential(replica, shared)

    # TODO: at the moment only support when the state is a vector
    state = replica.state
    dim = length(state)

    momentum_log_potential = 
        if explorer.adapted_momentum === nothing
            # before adaptation kicks in at the second round:
            ScaledPrecisionNormalLogPotential(1.0, dim)
        else
            explorer.adapted_momentum
        end

    # init v
    v = randn(rng, dim)

    step_size = explorer.base_step_size * dim^(-0.25) 
    if explorer.step_size_scalings !== nothing 
        step_size *= step_size_scalings[replica.chain]
    end
    n_leap_frog_until_refresh = ceil(Int, explorer.trajectory_length / step_size)

    for i in 1:explorer.n_refresh
        init_joint_log  = log_potential(state) + momentum_log_potential(v)
        @assert isfinite(init_joint_log)
        success, n_steps_to_go_back = hamiltonian_dynamics!(
            log_potential, momentum_log_potential, state, v, step_size, n_leap_frog_until_refresh,
            replica)

        if success # by success, we mean no NaN or -Inf were encountered along the trajectory
            final_joint_log = log_potential(state) + momentum_log_potential(v)
            @assert isfinite(final_joint_log)
            probability = min(1.0, exp(final_joint_log - init_joint_log))
            @record_if_requested!(replica.recorders, :explorer_acceptance_pr, (replica.chain, probability))
            if rand(rng) < probability 
                # accept: nothing to do, we work in-place
            else
                flip!(v)
                success, _ = hamiltonian_dynamics!(
                    log_potential, momentum_log_potential, state, v, step_size, n_steps_to_go_back, 
                    nothing)
                @assert success
                @assert init_joint_log ≈ log_potential(state) + momentum_log_potential(v)
            end
        else
            # we encountered a NaN or -Inf along the trajectory
            flip!(v)
            success, _ = hamiltonian_dynamics!(
                    log_potential, momentum_log_potential, state, v, step_size, n_steps_to_go_back, 
                    nothing)
            @assert success
            @assert init_joint_log ≈ log_potential(state) + momentum_log_potential(v)
        end

        # refreshment
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
    # See e.g., R. Neal, p.14. 
    # we add statistics collection for adaptation and tricks to make it 
    # non-allocating

    # keep previous grad to get directional curvature statistics
    grad = gradient(target_log_potential, x) 

    # first half-step
    v .= v .+ (step_size/2) .* grad

    for i in 1:n_steps 
        # more setup for directional curvature stats
        mom_grad = gradient(momentum_log_potential, v) 
        directional_before = dot(grad, mom_grad)
        mom_grad_norm = norm(mom_grad)

        # full step on position
        x .= x .- step_size .* mom_grad

        # support unwinding a trajectory taking us to numerical badness
        if !isfinite(target_log_potential(x))
            # we are in the middle of a step, undo it 
            x .= x .+ step_size .* mom_grad
            v .= v .- (step_size/2) .* grad
            # the other (full) leap frogs will be undone from the caller
            return false, (i-1)  # meaning: (failure, number of leap frogs after a flip to go back to starting point)
        end

        # compute and record directional curvature data point
        grad = gradient(target_log_potential, x) 
        directional_after = dot(grad, mom_grad) 
        second_dir_deriv = abs(directional_after - directional_before) / step_size / mom_grad_norm^2
        if replica !== nothing 
            @record_if_requested!(replica.recorders, :directional_second_derivatives, (replica.chain, second_dir_deriv))
        end

        # trick to merge successive half-steps
        if i != n_steps 
            v .= v .+ step_size .* grad
        end
    end

    # last half-step
    v .= v .+ (step_size/2) .* gradient(target_log_potential, x)

    return true, n_steps # meaning: (success, number of leap frogs to take after a flip if rejected)
end