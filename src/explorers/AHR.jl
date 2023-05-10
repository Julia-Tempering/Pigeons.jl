# Automatic Hit-and-Run: use Neal's slice sampler along a random ray
@kwdef struct AHR 
    w::Float64 = 10.0 # initial slice size
    p::Int = 20 # slices are no larger than 2^p * w
    n_passes::Int = 3 # n_passes through all variables per exploration step
end

@auto mutable struct Ray 
    start
    state
    direction 
    current
end

Base.getindex(ptr::Ray) = ptr.current 
function Base.setindex!(ptr::Ray, value)
    ptr.current = value
    ptr.state .= ptr.start .+ ptr.direction .* value
    return nothing
end


function step!(explorer::AHR, replica, shared) 
    slicer = SliceSampler(explorer.w, explorer.p, 1)
    log_potential = find_log_potential(replica, shared)
    rng = replica.rng
    state = replica.state
    for i in 1:explorer.n_passes 
        start = copy(state) 
        direction = randn(rng, length(start))
        direction ./= norm(direction) 
        pointer = Ray(start, state, direction, 0.0)
        z = log_potential(state) - rand(rng, Exponential(1.0))
        L, R = slice_double(slicer, state, z, pointer, log_potential, rng)
        pointer[] = slice_shrink(slicer, state, z, L, R, pointer, log_potential, rng)
    end
end