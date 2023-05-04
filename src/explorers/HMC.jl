@auto struct HMC
    # those are determined at the beginning:
    base_step_size::Float64 
    n_refresh::Int  # per exploration step

    adaptive_diag_mass_mtx::Bool 
    adaptive_epsilon::Bool

    # this gets updated if adaptive_diag_mass_mtx is enabled (set to 'nothing' until adapted)
    target_std_deviations

    # these get updated if  adaptive_epsilon is enabled (both set to 'nothing' until adapted)
    interpolated_curvatures
    step_size_scalings
end

max_n_steps(base_step_size, dim) = ceil(Int, 1.0 / base_step_size / dim^(-0.25))

"""
$SIGNATURES 

By default, adaptive schemes for a diagonal matrix and step size 
are enabled.
"""
HMC(base_step_size = 0.1, n_refresh = 3) = HMC(base_step_size, n_refresh, true, true, nothing, nothing, nothing)

static_HMC(base_step_size = 0.1, n_refresh = 3, target_std_deviations = nothing) =
    HMC(base_step_size, n_refresh, false, false, target_std_deviations, nothing,  nothing)

adapted(old::HMC, target_std_deviations, interpolated_curvatures, step_size_scalings) = 
    HMC(
        old.base_step_size, 
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
            sqrt.(get_statistic(reduced_recorders, :singleton_variable, Variance)) : 
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
    push!(result, momentum_buffer)
    push!(result, state_buffer)
    push!(result, gradient_buffer)
    push!(result, ones_buffer)

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
    
    shared_rng = rng_shared_by_all_replicas(shared.iterators)

    # TODO: at the moment only support when the state is a vector
    state = replica.state
    dim = length(state)

    momentum = get_buffer(replica.recorders.momentum_buffer, dim) 
    ones_buffer = get_buffer(replica.recorders.ones_buffer, dim)
    gradient_buffer = get_buffer(replica.recorders.gradient_buffer, dim)
    state_start = get_buffer(replica.recorders.state_buffer, dim)
    state_start .= state

    target_std_deviations = 
        if explorer.target_std_deviations === nothing 
            ones_buffer .= 1.0
            ones_buffer
        else 
            explorer.target_std_deviations
        end

    step_size = explorer.base_step_size * dim^(-0.25) 
    if explorer.step_size_scalings !== nothing 
        step_size *= explorer.step_size_scalings[replica.chain]
    end

    max_n_steps_between_refresh = max_n_steps(explorer.base_step_size, dim)

    hamiltonian() = log_potential(state) - 0.5 * sqr_norm(momentum)

    for i in 1:explorer.n_refresh

        # refreshment
        randn!(rng, momentum)

        # The natural thing would be:
        # n_steps = rand(shared_rng, 1:max_n_steps_between_refresh)
        # but it is creating allocations (!)
        n_steps = ceil(Int, rand(shared_rng) * max_n_steps_between_refresh)

        init_joint_log  = hamiltonian()
        @assert isfinite(init_joint_log)

        success = 
            hamiltonian_dynamics!(
                log_potential, target_std_deviations, state, momentum, step_size, n_steps,
                replica, gradient_buffer)

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
    end
end

# See e.g., R. Neal, p.14. 
# we add statistics collection for adaptation and tricks to make it 
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
        if !isfinite(target_log_potential(state))
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
    conditioned_target_gradient!()
    momentum .= momentum .+ (step_size/2) .* gradient_buffer

    return true
end

# build a shared rng to sync up the randomized number of steps 
# size across all replicas. This is not the highest quality 
# rng but good enough since it's for a relatively minor aspect 
# of sampling. Other solutions do not work because the reference 
# chain does not get step!() called. Also certainly don't want 
# to make shared writteable. 
rng_shared_by_all_replicas(iterators) = 
    SplittableRandom(11 + 7 * iterators.round + 3 * iterators.scan) 

momentum_buffer() = Augmentation{Vector{Float64}}() 
state_buffer() = Augmentation{Vector{Float64}}()
gradient_buffer() = Augmentation{Vector{Float64}}()
ones_buffer() = Augmentation{Vector{Float64}}()

function get_buffer(augmentation, dim::Int)::Vector{Float64}
    if augmentation.contents === nothing 
        augmentation.contents = zeros(dim) 
    end
    return augmentation.contents
end