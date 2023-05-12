"""
A bijection between integers and some type `T`. 
`T` is assumed to have consistent `hash` and `==`.
The two sides of the bijection can be obtained with the fields:
$FIELDS
"""
struct Indexer{T}
    """
    A `Vector` mapping **i**ntegers to objects **t** of type `T`.
    """
    i2t::Vector{T}

    """
    A `Dict` mapping objects **t** of type `T` to **i**ntegers.
    """
    t2i::Dict{T, Int}
end

"""
$SIGNATURES
Create an `Indexer` with the given `Int` to `T` mapping.
"""
function Indexer(i2t::AbstractVector{T}) where {T}
    t2i = Dict{T, Int}()
    for i in eachindex(i2t)
        t = i2t[i]
        t2i[t] = i
    end
    return Indexer(Vector(i2t), t2i)
end

