mutable struct Augmentation{T}
    contents::Union{T,Nothing}
    
    # when it is volatile, i.e. can be 
    # reconstructed on the fly and is only 
    # stored for efficiency purpose, it is 
    # not worth serialialinzing it
    serialize::Bool
end


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

