struct Immutable{K, T}
    data::T
    function Immutable(key::Type, data::T, lookup::Bool) where {T}
        if !lookup
            return new{key, T}(data)
        end
        if haskey(immutables, key) 
            @assert immutables[key] == data "Violation of singleton property"
        end
        immutables[key] = data
        return new{key, T}(data)
    end
end


Immutable(key::Type, data::T) where {T} = Immutable(key, data, true)

"""
$TYPEDSIGNATURES

Consider a situation where a distributed system serializes its state,  
and part of the state contains large immutable data.
When the distributed processes each independently call 
`Serialization.serialize()`, naively the processes would each write identical 
copies of the large immutable data, which is space-inefficient. 

To work around this space-inefficiency, `Immutable` can be used as follows: 

1. Enclose large data inside a `Immutable`. Use `key` to 
    distinguish between different data objects if needed. 
    Internally, we maintain an internal, global Dict indexed 
    by `Val{key}` storing the data. This global Dict is 
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
Immutable(key, data::T) where {T} = Immutable(Val{key}, data)

"""
$TYPEDSIGNATURES

Use the type of `data` as a default key.
"""
Immutable(data::T) where {T} = Immutable(T, data) 

const immutables = Dict{Type, Any}()

"""
$TYPEDSIGNATURES 

See [`Immutable()`](@ref).
"""
function serialize_immutables(filename::AbstractString)
    serialize(filename, immutables)
end

"""
$TYPEDSIGNATURES 

See [`Immutable()`](@ref).
"""
function deserialize_immutables(filename::AbstractString)
    merge!(immutables, deserialize(filename))
end

function Serialization.serialize(s::AbstractSerializer, instance::Immutable{K, T}) where {K, T}
    Serialization.writetag(s.io, Serialization.OBJECT_TAG)
    Serialization.serialize(s, Immutable{K, T})
end

function Serialization.deserialize(s::AbstractSerializer, type::Type{Immutable{K, T}}) where {K, T}
    @assert haskey(immutables, K) "Make sure to call deserialize_immutables(...) before rest of deserialization"
    return Immutable(K, immutables[K], false)
end
