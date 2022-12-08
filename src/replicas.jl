"""
replicas: an informal interface, implementations store the process' replicas. 
    Since we provide MPI implementations, do not assume that this will contain all the replicas, as 
    other can be located in other processes/machines

Implementations provided
    - EntangledReplicas: using an MPI-based implementation
    - Vector: for the single process case (above can handle that case, but the array based implementation is non-allocating)
"""
@informal replicas begin
    swap!(pair_swapper, replicas, swap_graph) = @abstract 
    """Return the replica's that are stored in this machine"""
    locals(replicas) = @abstract 
    """Return the load balancer"""
    load(replicas) = @abstract
    """Return the communicator or nothing if no MPI needed"""
    communicator(replicas) = @abstract 
    entangler(replicas) = @abstract 
end

# Non-distributed implementation allowing zero-allocation swaps:
locals(replicas::Vector) = replicas
load(replicas::Vector) = single_process_load(length(replicas))
communicator(replicas::Vector) = nothing
entangler(replicas::Vector) = Entangler(length(replicas); parent_communicator = nothing, verbose = false)

# the total number of chains across all processes
n_chains_global(replicas) = load(replicas).n_global_indices


"""Utility to initialize replicas' states"""
@informal state_initializer begin 
    initialization(state_initializer, rng::SplittableRandom, chain::Int) = @abstract
end
# ... initialize all to the same state
initialization(state_initializer::Ref, rng::SplittableRandom, chain::Int) = state_initializer[]
# ... initialize to a value specific to each chain
initialization(state_initializer::AbstractVector, rng::SplittableRandom, chain::Int) = state_initializer[chain]
# ... TODO: initialize from prior / other smart inits


function create_vector_replicas(n_chains::Int, state_initializer, rng::SplittableRandom)
    split_rngs = split_slice(1:n_chains, rng)
    states = [initialization(state_initializer, split_rngs[i], i) for i in eachindex(split_rngs)]
    recorders = [empty_recorder() for i in eachindex(split_rngs)]
    return Replica.(states, 1:n_chains, split_rngs, recorders)
end