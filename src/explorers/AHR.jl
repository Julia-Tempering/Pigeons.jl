# Automatic Hit-and-Run: use Neal's slice sampler along a random ray
@kwdef struct AHR 
    w::Float64 = 10.0 # initial slice size
    p::Int = 20 # slices are no larger than 2^p * w
    n_passes::Int = 3 # n_passes through all variables per exploration step
end

@auto struct Ray 
    start
    state
    direction 
end

function Base.setindex!(ptr::Ray, value)
    ptr.state .= ptr.start .+ ptr.direction .* value
    return nothing
end

Base.getindex(ptr::Ray) =
    (ptr.state[1] - ptr.start[1]) / ptr.direction[1]

function step!(explorer::AHR, replica, shared) 

    slicer = SliceSampler(explorer.w, explorer.p, 1)
    log_potential = find_log_potential(replica, shared)
    rng = replica.rng
    state = replica.state

    dim = length(state)
    state_buffer = get_buffer(replica.recorders.ahr_state_buffer, dim)
    direction_buffer = get_buffer(replica.recorders.ahr_direction_buffer, dim)

    for i in 1:explorer.n_passes 
        state_buffer .= state
        randn!(rng, direction_buffer)
        direction_buffer ./= norm(direction_buffer) 
        pointer = Ray(state_buffer, state, direction_buffer)
        z = log_potential(state) - rand(rng, Exponential(1.0))
        L, R = slice_double(slicer, state, z, pointer, log_potential, rng)
        pointer[] = slice_shrink(slicer, state, z, L, R, pointer, log_potential, rng)
    end
end

explorer_recorder_builders(hmc::AHR) = 
    [ahr_state_buffer, ahr_direction_buffer]

ahr_state_buffer() = Augmentation{Vector{Float64}}()
ahr_direction_buffer() = Augmentation{Vector{Float64}}()