"""
A distributed array making special assumptions on how 
it will be accessed and written to. 
The indices of this distributed array correspond to the 
notion of "global indices" defined in [`LoadBalance`](@ref). 
Several MPI processes cooperate, each processing storing 
data for a slice of this distributed array. 

We make the following assumptions:

- Each MPI process will set/get 
    entries the same number of times in their lifetime, at 
    logically related episodes (e.g. a set 
    number of times per iterations for algorithms running the 
    same number of iterations). 
    These episodes are called micro-iterations as in [`Entangler`](@ref), 
    which this datastructure is built on.

- Moreover, at each time all process perform a get or a set, 
    we assume that each global index is manipulated by exactly one 
    process (i.e. an implicit permutation of the global indices).

We use these assumptions to achieve  read/write costs that are 
near-constant in the number of machines participating. 

This struct contains:

$FIELDS

The operations supported are:

- [`permuted_get()`](@ref)
- [`permuted_set!()`](@ref)

"""
struct PermutedDistributedArray{T}
    """
    The slice of the distributed array maintained by this MPI process. 
    """
    local_data::Vector{T}

    """
    An [`Entangler`](@ref) used to coordinate communication. 
    """
    entangler::Entangler

    """
    $TYPEDSIGNATURES
    """
    function PermutedDistributedArray(my_initial_value::AbstractVector{T}, entangler::Entangler) where T
        @assert length(my_initial_value) == my_load(entangler.load)
        local_data = Vector(my_initial_value)
        return new{T}(local_data, entangler)
    end
end

"""
$TYPEDSIGNATURES

Retreive the values for the given `indices`, using MPI communication when needed. 

We make the following assumptions:

- `length(indices) == my_load(p.entangler.load)`
- the `indices` across all participating processes form a permutation of the global indices. 

"""
function permuted_get(p::PermutedDistributedArray{T}, indices::AbstractVector{Int})::Vector{T} where T
    @assert length(indices) == my_load(p.entangler.load)
    
    # make known your identity to your partners, i.e. share who want which piece of data
    global_indices_that_want_my_data = transmit(p.entangler, my_global_indices(p.entangler.load), indices)

    # send the actual data now that identity of who want what is known
    return transmit(p.entangler, p.local_data, global_indices_that_want_my_data)
end

"""
$TYPEDSIGNATURES

Set the values for the given `indices` to the given `new_values`, using MPI communication when needed. 

We make the same assumptions as in [`permuted_get()`](@ref).
"""
function permuted_set!(p::PermutedDistributedArray{T}, indices::AbstractVector{T}, new_values::AbstractVector{T}) where T
    @assert length(indices) == length(new_values) == my_load(p.entangler.load)

    transmit!(p.entangler, new_values, indices, p.local_data)
    return nothing
end

