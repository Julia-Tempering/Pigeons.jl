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