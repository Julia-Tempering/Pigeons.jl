"""
$SIGNATURES 

A state augmentation used by explorers. Internally, it hijacks the recorders 
machinery to store (usually volatile) data in a Replica. This helps with writing
allocation-light code by pre-allocating objects inside the Augmentation, while
avoiding race-conditions between replicas. For an application, see [`buffers`](@ref).

$FIELDS
"""
struct Augmentation{T}
    """
    The payload. Can be `nothing` for efficiency purposes. 
    """
    contents::Union{T,Nothing}
    
    """
    When it is volatile, i.e. can be 
    reconstructed on the fly and is only 
    stored for efficiency purpose, it is 
    not worth serializing it
    """
    serialize::Bool
end

# by default, do not serialize
Augmentation(contents) = Augmentation(contents, false)

# reducing Augmentations is meaningless; do minimum effort
Base.merge(::Augmentation{T}, ::Augmentation{T}) where {T} = Augmentation{T}(nothing, false)

# In this case we do not want to lose the augmentation at the end of the round
function Base.empty!(::Augmentation) end

function Serialization.serialize(s::AbstractSerializer, instance::Augmentation{T}) where {T}
    Serialization.writetag(s.io, Serialization.OBJECT_TAG)
    Serialization.serialize(s, Augmentation{T})
    Serialization.serialize(s, instance.serialize)
    if instance.serialize 
        Serialization.serialize(s, instance.contents)
    end
end

function Serialization.deserialize(s::AbstractSerializer, ::Type{Augmentation{T}}) where {T}
    serialize_field = Serialization.deserialize(s)
    contents = serialize_field ? Serialization.deserialize(s) : nothing
    return Augmentation{T}(contents, serialize_field)
end


"""
$SIGNATURES 

A buffering system used internally by explorers in Pigeons.
"""
buffers(::Type{T}=Vector{Float64}) where {T} = Augmentation(Dict{Symbol, T}())

"""
$SIGNATURES 

Return an array in the buffer. Allocating only the first 
time; after that, the buffer is recycled and stored in the 
Replica's recorders.
"""
function get_buffer(a::Augmentation{Dict{Symbol, T}}, key::Symbol, dims)::T where {T <: Array}
    dict = a.contents 
    if !haskey(dict, key) 
        dict[key] = similar(T, dims)
    end
    return dict[key]
end
