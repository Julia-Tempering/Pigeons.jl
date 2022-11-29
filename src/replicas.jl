"""
replicas: an informal interface, implementations store the process' replicas. 
    WARNING: Since we provide MPI implementations, DO NOT assume that this will contain all the replicas, as 
    other can be located in other processes/machines

Implementations provided
    - EntangledReplicas: using an MPI-based implementation
    - Vector: for the single process case (above can handle that case, but the array based implementation is non-allocating)
"""

# More info and implementations are in swap.jl
swap!(pair_swapper, replicas, swap_graph) = @abstract 

# return the replica's that are stored in this machine
locals(replicas) = @abstract 
locals(replicas::Vector) = replicas

# return the load balancer
load(replicas) = @abstract
load(replicas::Vector) = single_process_load(length(replicas))

# return the communicator or nothing if no MPI needed
communicator(replicas) = @abstract 
communicator(replicas::Vector) = nothing

# the total number of chains across all processes
n_chains_global(replicas) = load(replicas).n_global_indices


# utilities to initialize replicas
initialization(state_initializer, rng::SplittableRandom, chain::Int) = @abstract
# ... initialize all to the same state
initialization(state_initializer::Ref, rng::SplittableRandom, chain::Int) = state_initializer[]
# ... initialize to a value specific to each chain
initialization(state_initializer::AbstractVector, rng::SplittableRandom, chain::Int) = state_initializer[chain]
# ... TODO: initialize from prior / other smart inits


function create_vector_replicas(n_chains::Int, state_initializer, rng::SplittableRandom)
    split_rngs = split_slice(1:n_chains, rng)
    states = [initialization(state_initializer, split_rngs[i], i) for i in eachindex(split_rngs)]
    return Replica.(states, 1:n_chains, split_rngs)
end