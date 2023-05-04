@auto struct HMC
    # those are determined at the beginning:
    base_step_size::Float64 
    trajectory_length::Float64
    n_refresh::Int
    adaptive_diag_mass_mtx::Bool 
    adaptive_epsilon::Bool

    # this gets updated if adaptive_diag_mass_mtx is enabled (set to 'nothing' until adapted)
    target_std_deviations

    # these get updated if  adaptive_epsilon is enabled (both set to 'nothing' until adapted)
    interpolated_curvatures
    step_size_scalings
end


"""
$SIGNATURES 

By default, adaptive schemes for a diagonal matrix and step size 
are enabled.
"""
HMC() = HMC(0.1, 1.0, 3, true, true, nothing, nothing, nothing)

static_HMC(base_step_size::Float64, trajectory_length::Float64, n_refresh::Int, target_std_deviations = nothing) =
    HMC(base_step_size, trajectory_length, n_refresh, false, false, target_std_deviations, nothing,  nothing)

adapted(old::HMC, target_std_deviations, interpolated_curvatures, step_size_scalings) = 
    HMC(
        old.base_step_size, 
        old.trajectory_length,
        old.n_refresh,
        old.adaptive_diag_mass_mtx, 
        old.adaptive_epsilon, 
        target_std_deviations, interpolated_curvatures, step_size_scalings)

step_size_scalings(interpolated, points) = 1.0 ./ sqrt.(exp.(interpolated.(points)))

function adapt_explorer(explorer::HMC, reduced_recorders, current_pt, new_tempering)
    if !explorer.adaptive_diag_mass_mtx && !explorer.adaptive_epsilon
        return explorer
    end

    target_std_dev = 
        explorer.adaptive_diag_mass_mtx ? 
            get_statistic(reduced_recorders, :singleton_variable, Variance) : 
            nothing
    
    if explorer.adaptive_epsilon
        # Build an interpolation from the worst-curvature estimates
        betas = current_pt.shared.tempering.schedule.grids
        curvature_estimates = value(reduced_recorders.directional_second_derivatives)
        ys = zeros(length(betas))
        for i in eachindex(betas) 
            j = i == 1 ? 2 : i # TODO: will need to change for 2 refs 
            # we will fit the spline in log scale, then exp.() after interpolation to ensure positivity
            ys[i] = log(maximum(curvature_estimates[j])) 
        end
        interpolated = BSplineKit.interpolate(betas, ys, BSplineOrder(4))

        # heuristic based on R. Neal 2012, 'MCMC using Hamiltonian dynamics' just below equation (4.7)
        step_size_scalings_ = step_size_scalings(interpolated, new_tempering.schedule.grids)
    else
        interpolated = nothing
        step_size_scalings_ = nothing
    end
    
    return adapted(
            explorer, 
            target_std_dev, 
            interpolated,
            step_size_scalings_
        )
end

function explorer_recorder_builders(hmc::HMC) 
    result = Function[]
    push!(result, explorer_acceptance_pr)
    if hmc.adaptive_diag_mass_mtx
        push!(result, target_online)
    end
    if hmc.adaptive_epsilon
        push!(result, directional_second_derivatives)
    end
    return result
end

function step!(explorer::HMC, replica, shared)   
    rng = replica.rng
    log_potential = find_log_potential(replica, shared)

    # TODO: at the moment only support when the state is a vector
    state = replica.state
    dim = length(state)

    target_std_deviations = 
        explorer.target_std_deviations === nothing ? 
            ones(dim) :
            explorer.target_std_deviations

    # init v
    v = randn(rng, dim) # !!!! TODO: make this non-alloc
    state_start = copy(state)

    step_size = explorer.base_step_size * dim^(-0.25) 
    if explorer.step_size_scalings !== nothing 
        step_size *= explorer.step_size_scalings[replica.chain]
    end

    # TODO: randomize the trajectory length using a separate SplittableRandom

    n_leap_frog_until_refresh = ceil(Int, explorer.trajectory_length / step_size)

    hamiltonian() = log_potential(state) - 0.5 * sqr_norm(v)

    for i in 1:explorer.n_refresh
        init_joint_log  = hamiltonian()
        @assert isfinite(init_joint_log)
        success = hamiltonian_dynamics!(
            log_potential, target_std_deviations, state, v, step_size, n_leap_frog_until_refresh,
            replica)

        if success # by success, we mean no NaN or -Inf were encountered along the trajectory
            final_joint_log = hamiltonian()
            @assert isfinite(final_joint_log)
            probability = min(1.0, exp(final_joint_log - init_joint_log))
            @record_if_requested!(replica.recorders, :explorer_acceptance_pr, (replica.chain, probability))
            
            # TODO: add optional reversibility check
            
            if rand(rng) < probability 
                # accept: nothing to do, we work in-place
            else
                state .= state_start
            end
        else
            # we encountered something not finite along the trajectory
            state .= state_start
        end

        # refreshment
        randn!(rng, v)
    end
end

function hamiltonian_dynamics!(
        target_log_potential, 
        target_std_deviations, 
        x, v, step_size, n_steps, 
        replica)

    # We use an implicit linear transformation rescaling  
    # component i with 1/target_std_deviations[i]
    # and use an isotropic normal momentum. 
    # We use this instead of the equivalent momentum with a mass matrix
    # formulation so that we can estimate the residual curvature induced 
    # by correlations not captured by matching the componentwise 
    # moments. 
    conditioned_target_gradient() = 
        gradient(target_log_potential, x) .* 
            target_std_deviations 

    # See e.g., R. Neal, p.14. 
    # we add statistics collection for adaptation and tricks to make it 
    # non-allocating

    # keep previous grad to get directional curvature statistics
    grad = conditioned_target_gradient()

    # first half-step
    v .= v .+ (step_size/2) .* grad

    for i in 1:n_steps 
        # more setup for directional curvature stats
        directional_before = -dot(grad, v)

        # full step on position
        x .= x .+ step_size .* v .* target_std_deviations

        # TODO: bounce
        if !isfinite(target_log_potential(x))
            return false
            # # we are in the middle of a step, undo it 
            # x .= x .+ step_size .* mom_grad
            # v .= v .- (step_size/2) .* grad
            # # the other (full) leap frogs will be undone from the caller
            # return false, (i-1)  # meaning: (failure, number of leap frogs after a flip to go back to starting point)
        end

        # compute and record directional curvature data point
        grad = conditioned_target_gradient()

        directional_after = -dot(grad, v) 

        second_dir_deriv = abs(directional_after - directional_before) / step_size / sqr_norm(v)
        if replica !== nothing && 
            isfinite(second_dir_deriv) # in case e.g. norm of v is very small
            @record_if_requested!(replica.recorders, :directional_second_derivatives, (replica.chain, second_dir_deriv))
        end

        # Neal's trick to merge successive half-steps
        if i != n_steps 
            v .= v .+ step_size .* grad
        end
    end

    # last half-step
    v .= v .+ (step_size/2) .* conditioned_target_gradient()

    return true
end