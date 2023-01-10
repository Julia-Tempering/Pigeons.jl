struct Immutable{T}
    hash::UInt
    data::T
    # private constructor - do not use directly
    function Immutable(data::T, lookup::Bool) where {T}
        key = hash(data)
        if !lookup
            return new{T}(key, data)
        end
        if haskey(immutables, key) 
            @assert immutables[key] == data "Type $T should have consistent == and hash"
        end
        immutables[key] = data
        return new{T}(key, data)
    end
end


"""
$SIGNATURES

Consider a situation where a distributed system serializes its state,  
and part of the state contains large immutable data.
When the distributed processes each independently call 
`Serialization.serialize()`, naively the processes would each write identical 
copies of the large immutable data, which is space-inefficient. 

To work around this space-inefficiency, `Immutable` can be used as follows: 

1. Enclose large immutable data inside a `Immutable`. 
    Assume the type of data has well defined hash and ==.
    Internally, we maintain an internal, global Dict indexed 
    by hash(data) storing the data. This global Dict is 
    called `immutables`.
2. Use `Serialization.serialize` as usual. Internally, we 
    dispatch serialization of `Immutable` is modified to skip 
    the field containing the data.
3. Make one of the processes call [`serialize_immutables()`](@ref). 
    This serializes the `immutables` Dict.
4. Then for de-serialization, each process should call 
    [`deserialize_immutables()`](@ref). This restores 
    `immutable`.
5. Finally, call `Serialization.deserialize()` as usual. 
    When an `Immutable` instances is being deserialize, we 
    dispatch deserialization so that the data is retreived 
    from `immutable`.
"""
Immutable(data) = Immutable(data, true)

const immutables = Dict{UInt, Any}()

"""
$SIGNATURES 

See [`Immutable()`](@ref).
"""
function serialize_immutables(filename::AbstractString)
    serialize(filename, immutables)
end

"""
$SIGNATURES 

See [`Immutable()`](@ref).
"""
function deserialize_immutables(filename::AbstractString)
    empty!(immutables)
    merge!(immutables, deserialize(filename))
end

function Serialization.serialize(s::AbstractSerializer, instance::Immutable{T}) where {T}
    Serialization.writetag(s.io, Serialization.OBJECT_TAG)
    Serialization.serialize(s, Immutable{T})
    Serialization.serialize(s, instance.hash)
end

function Serialization.deserialize(s::AbstractSerializer, type::Type{Immutable{T}}) where {T}
    key = Serialization.deserialize(s)
    @assert haskey(immutables, key) "Make sure to call deserialize_immutables(...) before rest of deserialization"
    return Immutable(immutables[key], false)
end
