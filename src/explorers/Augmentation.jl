"""
A state augmentation used by explorers. 

Internally, hijacks the recorders machinery to 
store it in a Replica. 
"""
mutable struct Augmentation{T}
    """
    The payload, initially nothing until 
    [`get_buffer()`](@ref) is called.
    """
    contents::Union{T,Nothing}
    
    """
    When it is volatile, i.e. can be 
    reconstructed on the fly and is only 
    stored for efficiency purpose, it is 
    not worth serialialinzing it
    """
    serialize::Bool
end

buffers() = Augmentation(Dict{Symbol, Vector{Float64}}(), false)

"""
$SIGNATURES 

Return a Vector of length dim. Allocating only the first 
time, after that the buffer is recycled and stored in the 
Replica's recorders. 
"""
function get_buffer(augmentation, key::Symbol, dim::Int)::Vector{Float64}
    dict = augmentation.contents 
    if !haskey(dict, key) 
        dict[key] = zeros(dim) 
    end
    return dict[key]
end

Augmentation{T}() where {T} = Augmentation{T}(nothing, false)

Base.merge(a1::Augmentation{T}, a2::Augmentation{T}) where {T} = 
    Augmentation{T}(nothing, false) 

# In this case we do not want to lose the augmentation at the end of the round
Base.empty!(a::Augmentation) = nothing

function Serialization.serialize(s::AbstractSerializer, instance::Augmentation{T}) where {T}
    Serialization.writetag(s.io, Serialization.OBJECT_TAG)
    Serialization.serialize(s, Augmentation{T})
    Serialization.serialize(s, instance.serialize)
    if instance.serialize 
        Serialization.serialize(s, instance.contents)
    end
end

function Serialization.deserialize(s::AbstractSerializer, type::Type{Augmentation{T}}) where {T}
    serialize_field = Serialization.deserialize(s)
    contents = serialize_field ? Serialization.deserialize(s) : nothing
    return Augmentation{T}(contents, serialize_field)
end

