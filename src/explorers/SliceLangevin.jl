# Automatic Hit-and-Run: use Neal's slice sampler along a random ray
@kwdef struct SliceLangevin 
    w::Float64 = 10.0 # initial slice size
    p::Int = 20 # slices are no larger than 2^p * w
    n_passes::Int = 3 # n_passes through all variables per exploration step
end

@auto struct LangevinInvolutions 
    start_state
    start_momentum
    target_log_potential 
    target_std_deviations 
    state
    momentum
    gradient_buffer
end

function Base.setindex!(ptr::LangevinInvolutions, step_size)
    ptr.state .= ptr.start_state 
    ptr.momentum .= ptr.start_momentum
    leaf_frog!(
        ptr.target_log_potential, 
        ptr.target_std_deviations, 
        ptr.state, ptr.momentum, step_size,
        ptr.gradient_buffer)
    return nothing
end

# This only gets called at the very beginning so always zero.
# TODO: fix SliceSampler to take a function to avoid this hack:
Base.getindex(ptr::LangevinInvolutions) = 0.0 

function debug_objective(dim = 2, rng = SplittableRandom(1))
    log_potential = Pigeons.ScaledPrecisionNormalLogPotential(1.1, dim) 
    
    state = randn(rng, dim)
    momentum = zeros(dim) 
    momentum_start = zeros(dim) 
    ones_buffer = ones(dim) 
    gradient_buffer = zeros(dim) 
    state_start = zeros(dim) 

    joint(_) = log_potential(state) - 0.5 * sqr_norm(momentum) 


        state_start .= state
        randn!(rng, momentum)
        momentum_start .= momentum
        pointer = LangevinInvolutions(
            state_start,
            momentum_start,
            log_potential,
            ones_buffer, 
            state,
            momentum,
            gradient_buffer)
    
    function result(value) 
        pointer[] = value 
        return joint(nothing)
    end

    return result
end

function step!(explorer::SliceLangevin, replica, shared) 

    slicer = SliceSampler(explorer.w, explorer.p, 1)
    log_potential = find_log_potential(replica, shared.tempering, shared)
    rng = replica.rng
    state = replica.state

    dim = length(state)
    
    momentum = get_buffer(replica.recorders.momentum_buffer, dim) 
    momentum_start = get_buffer(replica.recorders.sl_start_momentum_buffer, dim)
    ones_buffer = get_buffer(replica.recorders.ones_buffer, dim)
    ones_buffer .= 1.0
    gradient_buffer = get_buffer(replica.recorders.gradient_buffer, dim)
    state_start = get_buffer(replica.recorders.state_buffer, dim)

    joint(_) = log_potential(state) - 0.5 * sqr_norm(momentum)

    # TODO mass matrix adapt stuff

    
    for i in 1:explorer.n_passes 
        state_start .= state
        randn!(rng, momentum)
        momentum_start .= momentum
        cached_lp = joint(state)
        pointer = LangevinInvolutions(
            state_start,
            momentum_start,
            log_potential,
            ones_buffer, 
            state,
            momentum,
            gradient_buffer)
        z = cached_lp - rand(rng, Exponential(1.0))
        L, R, lp_L, lp_R = slice_double(slicer, replica, z, pointer, joint)
        cached_lp = slice_shrink!(slicer, replica, z, L, R, lp_L, lp_R, pointer, joint)
    end
end

sl_start_momentum_buffer() = Augmentation{Vector{Float64}}()

explorer_recorder_builders(hmc::SliceLangevin) = 
    [momentum_buffer, sl_start_momentum_buffer, state_buffer, gradient_buffer, ones_buffer, explorer_acceptance_pr, explorer_n_steps]
