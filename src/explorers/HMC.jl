@auto struct HMC
    # those are determined at the beginning:

        base_step_size::Float64 
        n_refresh::Int  # per exploration step

        # instead of adaptation being on/off, use a probability to avoid adaptation pathologies, e.g. not moving in first iter, getting bad std dev estimates, and feedback
        adaptive_diag_mass_mtx_pr::Float64 # probability to use mass matrix adaptation
        adaptive_step_size_pr::Float64     # same for step_size

    # this gets updated if adaptive_diag_mass_mtx is enabled (set to 'nothing' until adapted)
     
        target_std_deviations

    # these get updated if  adaptive_epsilon is enabled (both set to 'nothing' until adapted)
    
        interpolated_curvatures
        step_size_scalings
end

# We randomize number of steps between 1 and max_n_steps()
# This simple heuristic allows us to have all replicas use the same # of steps 
# The goal here is not to explore the space exhaustively, only to reduce 
# AC on the induced chain W_i = log_density(X_i)
max_n_steps(base_step_size, dim) = ceil(Int, 1.0 / base_step_size / dim^(-0.25))

"""
$SIGNATURES 

By default, adaptive schemes for a diagonal matrix and step size 
are enabled.
"""
HMC(base_step_size = 0.1, n_refresh = 3, adapt_pr = 0.8) = HMC(base_step_size, n_refresh, adapt_pr, adapt_pr, nothing, nothing, nothing)

# For testing:
static_HMC(base_step_size = 0.1, n_refresh = 3, target_std_deviations = nothing) =
    HMC(base_step_size, n_refresh, 0.0, 0.0, target_std_deviations, nothing,  nothing)

adapted(old::HMC, target_std_deviations, interpolated_curvatures, step_size_scalings) = 
    HMC(
        old.base_step_size, 
        old.n_refresh,
        old.adaptive_diag_mass_mtx_pr, 
        old.adaptive_step_size_pr, 
        target_std_deviations, interpolated_curvatures, step_size_scalings)

step_size_scalings(interpolated, points) = 1.0 ./ sqrt.(log1pexp.(interpolated.(points)))

function adapt_explorer(explorer::HMC, reduced_recorders, current_pt, new_tempering)
    
    if explorer.adaptive_diag_mass_mtx_pr == 0.0 && explorer.adaptive_step_size_pr == 0.0
        return explorer
    end
    
    @assert new_tempering isa NonReversiblePT "TODO: generalize to 2-legged after branch merge"
    
    target_std_dev = 
        explorer.adaptive_diag_mass_mtx_pr > 0.0 ? 
            sqrt.(get_statistic(reduced_recorders, :singleton_variable, Variance)) : 
            nothing
    
    if explorer.adaptive_step_size_pr > 0.0
        # Build an interpolation from the worst-curvature estimates
        betas = current_pt.shared.tempering.schedule.grids
        curvature_estimates = value(reduced_recorders.directional_second_derivatives)
        ys = zeros(length(betas))
        worst_curvature = 
            isempty(curvature_estimates) ?
                1.0 : # could happen in earlier iterations
                maximum(maximum.(values(curvature_estimates)))
        for i in eachindex(betas) 
            current_curvature_estimate = 
                if haskey(curvature_estimates, i) 
                    # typical case
                    maximum(curvature_estimates[i])
                elseif haskey(curvature_estimates, i - 1)
                    # the other cases are for (1) prior for which we do not get explorer info (sampled iid instead)
                    # (2) early iterations where some chain may not have yet succeeded in moving
                    maximum(curvature_estimates[i - 1])
                elseif haskey(curvature_estimates, i + 1)
                    maximum(curvature_estimates[i + 1])
                else
                    # if neither neighbour is available (e.g. from case (2))
                    # assume the worst case
                    worst_curvature
                end

            # we will fit the spline in log scale, then exp.() after interpolation to ensure positivity
            ys[i] = logexpm1(current_curvature_estimate)
        end

        if length(betas) == 1 
            # a single chain: "interpolation" is just a constant function
            interpolated(_) = ys[1]
        else
            interpolated = BSplineKit.interpolate(betas, ys, BSplineOrder(4)) # order 4 is a cubic spine in BSplineOrder
        end
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

    if hmc.adaptive_diag_mass_mtx_pr > 0.0
        push!(result, target_online)
    end
    if hmc.adaptive_step_size_pr > 0.0
        push!(result, directional_second_derivatives)
    end
    return result
end

hamiltonian(logp, state, momentum) = logp(state) - 0.5 * sqr_norm(momentum)

function step!(explorer::HMC, replica, shared, step_size_ = nothing, n_steps_ = nothing)   
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

    adapt_choice_draw = rand(rng)
    use_mass_matrix_adapt = adapt_choice_draw < explorer.adaptive_diag_mass_mtx_pr
    use_step_size_adapt = adapt_choice_draw < explorer.adaptive_step_size_pr

    # TODO: should not have to do that, generalize the stuff to take in nothing
    target_std_deviations = 
        if explorer.target_std_deviations === nothing || !use_mass_matrix_adapt
            # we won't use diagonal mass matrix
            ones_buffer .= 1.0
            ones_buffer
        else 
            explorer.target_std_deviations
        end

    if step_size_ === nothing
        step_size = explorer.base_step_size * dim^(-0.25) 
        if explorer.step_size_scalings !== nothing && use_step_size_adapt
            # the mass matrix misses some of the curvature, 
            # this attempts to correct it
            step_size *= explorer.step_size_scalings[replica.chain]
        end
    else
        step_size = step_size_
    end

    max_n_steps_between_refresh = max_n_steps(explorer.base_step_size, dim)

    for i in 1:explorer.n_refresh

        # refreshment
        randn!(rng, momentum)

        # The natural thing would be:
        # n_steps = rand(shared_rng, 1:max_n_steps_between_refresh)
        # but it is creating allocations (!)
        if n_steps_ === nothing
            n_steps = ceil(Int, rand(shared_rng) * max_n_steps_between_refresh)
        else 
            n_steps = n_steps_
        end

        init_joint_log  = hamiltonian(log_potential, state, momentum)
        @assert isfinite(init_joint_log)

        success = 
            hamiltonian_dynamics!(
                log_potential, target_std_deviations, state, momentum, step_size, n_steps,
                replica, gradient_buffer)

        if success # by success, we mean no NaN or -Inf were encountered along the trajectory
            final_joint_log = hamiltonian(log_potential, state, momentum)
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
            @record_if_requested!(replica.recorders, :explorer_acceptance_pr, (replica.chain, 0.0))
        end
    end
end

function adaptive_leap_frog_objective(
        target_log_potential, 
        target_std_deviations, 
        state, momentum, 
        gradient_buffer)

    # TODO: pass those as buffers
    state_before = copy(state)
    momentum_before = copy(momentum)

    h_before = hamiltonian(target_log_potential, state, momentum)

    function objective(step_size)
        leaf_frog!(target_log_potential, target_std_deviations, state, momentum, step_size, gradient_buffer)
        h_after = hamiltonian(target_log_potential, state, momentum)
        state .= state_before 
        momentum .= momentum_before
        return h_after - h_before
    end

    return objective
end

function adaptive_leap_frog!(
        target_log_potential, 
        target_std_deviations, 
        state, momentum, 
        gradient_buffer)
    obj = adaptive_leap_frog_objective(
            target_log_potential, 
            target_std_deviations, 
            state, momentum, 
            gradient_buffer)
    step_size = 
        # if adaptive_leap_frog_objective_derivative_sign(obj) > 0.0
        #     find_zero(obj)
        # else
            find_target(obj, 0.05) 
        # end
    leaf_frog!(target_log_potential, target_std_deviations, state, momentum, step_size, gradient_buffer)
    return step_size
end

function find_zero(obj)
    right = 1.0
    while obj(right) > 0.0 
        right *= 2.0 
    end
    return Roots.find_zero(obj, (1e-5, right))
end

function find_target(obj, alpha) 
    @assert alpha > 0.0
    right = 1.0 
    while abs(obj(right)) < alpha 
        right *= 2.0
    end
    target_alpha = sign(obj(right)) * alpha 
    translated(x) = obj(x) - target_alpha 
    return Roots.find_zero(translated, (0.0, right))

    # translated(x) = obj(x) + alpha 
    # right = 1.0 
    # while translated(right) > 0.0 
    #     right *= 2.0 
    # end
    # return Roots.find_zero(translated, (0.0, right))
end

function adaptive_leap_frog_objective_derivative_sign(obj)
    # TODO: fix ForwardDiff or write close form expression 
    return sign(obj(1e-5))
end


leaf_frog!(
        target_log_potential, 
        target_std_deviations, 
        state, momentum, step_size,
        gradient_buffer) =
    # TODO: implement directly if settle here 
    hamiltonian_dynamics!(
            target_log_potential, 
            target_std_deviations, 
            state, momentum, step_size, 1, 
            nothing, gradient_buffer)


# See e.g., R. Neal, p.14. 
# we add a cheap curvature estimator for adaptation and tricks to make it 
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
        if !isfinite(hamiltonian(target_log_potential, state, momentum))
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
    momentum .= momentum .+ (step_size/2) .* gradient_buffer

    if !isfinite(hamiltonian(target_log_potential, state, momentum))
        return false
    end

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