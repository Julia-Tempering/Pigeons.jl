"""
An implementation of [`replicas`](@ref) for distributed PT. 
Contains:
$FIELDS
"""
@auto struct EntangledReplicas # implements the informal interface in replica.jl
    """
    The subset of replicas hosted in this process
    """
    locals
    
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
$SIGNATURES
Create distributed replicas. 

See [`create_replicas`](@ref).
"""
@provides replicas function create_entangled_replicas(inputs::Inputs, shared::Shared, source)
    n = n_chains(inputs)
    entangler = Entangler(n)
    my_globals = my_global_indices(entangler.load)
    chain_to_replica_global_indices = PermutedDistributedArray(my_globals, entangler)
    locals = _create_locals(my_globals, inputs, shared, source)
    return EntangledReplicas(locals, chain_to_replica_global_indices)
end