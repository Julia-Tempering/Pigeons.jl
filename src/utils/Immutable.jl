struct Immutable{T}
    hash::UInt
    data::T
    
    """
    $SIGNATURES

    Consider a situation where a distributed system serializes its state,  
    and part of the state contains large immutable data.
    When the distributed processes each independently call 
    `Serialization.serialize()`, naively the processes would each write identical 
    copies of the large immutable data, which is space-inefficient. 

    `Immutable` resolves this space-inefficiency. For most users, 
    all they need to know is to enclose large data inside the 
    struct `Immutable`. 

    Details of how serialization/deserialization is performed:

    1. Enclose large immutable data inside a `Immutable`. 
        Assume the type of data has well defined hash and ==.
        Internally, we maintain a global Dict indexed 
        by hash(data) storing the data. This global Dict is 
        called `immutables`.
    2.  Use flush_immutable() to clear the global immutable state
    3. Use `Serialization.serialize` as usual. Internally, we 
        dispatch serialization of `Immutable` is modified to skip 
        the field containing the data.
    4. Make one of the processes call [`serialize_immutables()`](@ref). 
        This serializes the `immutables` Dict.
    5. Then for de-serialization, each process should call 
        [`deserialize_immutables!()`](@ref). This restores 
        `immutable`.
    6. Finally, call `Serialization.deserialize()` as usual. 
        When an `Immutable` instances is being deserialized, we 
        dispatch deserialization so that the data is retreived 
        from `immutables`.
    """
    function Immutable(data::T) where {T}
        key = hash(data)
        return new{T}(key, data)
    end
end

const immutables = Dict{UInt, Any}()

"""
$SIGNATURES 

See `Immutable`'s.
"""
function flush_immutables!()
    empty!(immutables)
end

"""
$SIGNATURES 

See `Immutable`'s.
"""
function serialize_immutables(filename::AbstractString)
    serialize(filename, immutables)
    flush_immutables!()
end

"""
$SIGNATURES 

See `Immutable`'s.
"""
function deserialize_immutables!(filename::AbstractString)
    empty!(immutables)
    merge!(immutables, deserialize(filename))
end

function Serialization.serialize(s::AbstractSerializer, instance::Immutable{T}) where {T}
    Serialization.writetag(s.io, Serialization.OBJECT_TAG)
    Serialization.serialize(s, Immutable{T})
    Serialization.serialize(s, instance.hash)
    immutables[instance.hash] = instance.data
end

function Serialization.deserialize(s::AbstractSerializer, type::Type{Immutable{T}}) where {T}
    key = Serialization.deserialize(s)
    @assert haskey(immutables, key) "Make sure to call deserialize_immutables!(...) before rest of deserialization"
    return Immutable(immutables[key])
end
