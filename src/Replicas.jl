"""
Low-level structs used for swapping. 
"""

mutable struct Replica{S}
    state::S
    chain::Int # Terminology (as in JRSSB NRPT paper): chain=i means we are currently using beta_i for that replica 
    rng::SplittableRandom
end
chain(r::Replica) = r.chain

struct Replicas{S} # A collection of replicas - see below for a convenient way to create 
    # the subset of replicas hosted in this process, indexed by a 'local index' with no specific meaning
    locals::Vector{Replica{S}} 
    # maps 'chain's to 'global indices', where the latter is used to keep track of all replicas split across many processes
    chain_to_replica_global_indices::PermutedDistributedArray{Int} 
end
entangler(r::Replicas) = r.chain_to_replica_global_indices.entangler # an 'entangler' encapsulates the MPI details
load(r::Replicas) = entangler(r).load # load balancing information

# utilities to initialize Replicas
initialization(initializer, rng::SplittableRandom, chain::Int) = @abstract
# ... initialize all to the same state
struct ConstantInitializer{S}
    init::S 
end
initialization(initializer::ConstantInitializer, rng::SplittableRandom, chain::Int) = initializer.init
# ... TODO: initialize from prior / with some 'nothing' convention / others

function Replicas(n_chains::Int, initializer, rng::SplittableRandom, useMPI::Bool) where S
    entangler = Entangler(n_chains, parent_communicator = (useMPI ? COMM_WORLD : nothing))
    my_globals = my_global_indices(entangler.load)
    chain_to_replica_global_indices = PermutedDistributedArray(my_globals, entangler)
    split_rngs = split_slice(my_globals, rng)
    states = [initialization(initializer, split_rngs[i], my_globals[i]) for i in eachindex(split_rngs)]
    locals = Replica.(states, my_globals, split_rngs)
    return Replicas(locals, chain_to_replica_global_indices)
end

