struct EntangledReplicas{R} # implements the informal interface in replica.jl
    # the subset of replicas hosted in this process, indexed by a 'local index' with no specific meaning
    locals::Vector{R} 
    # maps 'chain's to 'global indices', where the latter is used to keep track of all replicas split across many processes
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
@provides replicas function create_entangled_replicas(n_chains::Int, state_initializer, rng::SplittableRandom, useMPI::Bool = true)
    entangler = Entangler(n_chains, parent_communicator = (useMPI ? COMM_WORLD : nothing))
    my_globals = my_global_indices(entangler.load)
    chain_to_replica_global_indices = PermutedDistributedArray(my_globals, entangler)
    split_rngs = split_slice(my_globals, rng)
    states = [initialization(state_initializer, split_rngs[i], my_globals[i]) for i in eachindex(split_rngs)]
    recorders = [default_recorders() for i in eachindex(split_rngs)]
    locals = Replica.(states, my_globals, split_rngs, recorders)
    return EntangledReplicas(locals, chain_to_replica_global_indices)
end