struct Indexer{T}
    i2t::Vector{T}
    t2i::Dict{T, Int}
end

function Indexer(i2t::AbstractVector{T}) where {T}
    t2i = Dict{T, Int}()
    for i in eachindex(i2t)
        t = i2t[i]
        t2i[t] = i
    end
    return Indexer(Vector(i2t), t2i)
end
