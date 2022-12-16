"""
An implementation of [`replicas`](@ref) for distributed PT. 
Contains:
$FIELDS
"""
struct EntangledReplicas{R} # implements the informal interface in replica.jl
    """
    The subset of replicas hosted in this process
    """
    locals::Vector{R}
    
    """
    A specialized distributed array that 
    maps chain indices to replica indices (global indices).
    This corresponds to the mapping ``\\boldsymbol{j}`` in line 2 of 
    Algorithm 5 in [Syed et al, 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
    """
    chain_to_replica_global_indices::PermutedDistributedArray{Int} 
end
entangler(r::EntangledReplicas) = r.chain_to_replica_global_indices.entangler # an 'entangler' encapsulates the MPI details
load(r::EntangledReplicas) = entangler(r).load # load balancing information
locals(r::EntangledReplicas) = r.locals
communicator(r::EntangledReplicas) = entangler(r).communicator

"""
$TYPEDSIGNATURES
Create distributed replicas. The argument `useMPI = false` is only for debugging purpose.
See also [`state_initializer`](@ref). 
"""
@provides replicas function create_entangled_replicas(
        n_chains::Int, 
        state_initializer, 
        rng::SplittableRandom, 
        useMPI::Bool = true,
        recorder_keys::Set{Symbol} = Set{Symbol}())
    entangler = Entangler(n_chains, parent_communicator = (useMPI ? COMM_WORLD : nothing))
    my_globals = my_global_indices(entangler.load)
    chain_to_replica_global_indices = PermutedDistributedArray(my_globals, entangler)
    split_rngs = split_slice(my_globals, rng)
    states = [initialization(state_initializer, split_rngs[i], my_globals[i]) for i in eachindex(split_rngs)]
    recorders = [custom_recorders(recorder_keys) for i in eachindex(split_rngs)]
    locals = Replica.(states, my_globals, split_rngs, recorders, my_globals)
    return EntangledReplicas(locals, chain_to_replica_global_indices)
end