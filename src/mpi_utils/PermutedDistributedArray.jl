"""
A distributed array making special assumptions on how 
it will be accessed and written to.

These assumptions allow for read/write costs that are 
near-constant in the number of machines participating. 

Specifically, we assume that each MPI process will set/get 
entries the same number of times in their lifetime, at 
logically related intervals (e.g. a set 
number of times per iterations for algorithms running the 
same number of iterations). 
Moreover, at each time all process perform a get or a set, 
we assume that each index is manipulated by exactly one 
process (i.e. an implicit permutation of the process indices).

See test/permuted_test.jl for an example. 
"""
struct PermutedDistributedArray{T}
    local_data::Vector{T}
    entangler::Entangler
    function PermutedDistributedArray(my_initial_value::AbstractVector{T}, entangler::Entangler) where T
        @assert length(my_initial_value) == my_load(entangler.load)
        local_data = Vector(my_initial_value)
        return new{T}(local_data, entangler)
    end
end

function permuted_get(p::PermutedDistributedArray{T}, indices::AbstractVector{Int})::Vector{T} where T
    @assert length(indices) == my_load(p.entangler.load)
    
    # make known your identity to your partners, i.e. share who want which piece of data
    global_indices_that_want_my_data = transmit(p.entangler, my_global_indices(p.entangler.load), indices)

    # send the actual data now that identity of who want what is known
    return transmit(p.entangler, p.local_data, global_indices_that_want_my_data)
end

function permuted_set!(p::PermutedDistributedArray{T}, indices::AbstractVector{T}, new_values::AbstractVector{T}) where T
    @assert length(indices) == length(new_values) == my_load(p.entangler.load)

    transmit!(p.entangler, new_values, indices, p.local_data)
    return nothing
end

