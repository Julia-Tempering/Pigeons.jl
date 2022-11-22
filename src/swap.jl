"""
Perform one round of swaps. 

This implementation is designed to support distributed PT with the following guarantees
    - The running time is independent of the size of the state space 
      ('swapping annealing parameters rather than states')
    - The output is identical no matter how many MPI processes are used. In particular, 
      this means that we can check correctness by comparing to the serial, # process = 1 version.
    - Scalability to 1000s of processes communicating over MPI (see details below).
    - The same function can be used when a single process is used and MPI is not available.
    - Flexibility to extend PT to e.g. networks of targets and general paths.

For more information on input argument..
    - swapper, see below, example in test/swap_test.jl, and [TODO: default implementation at ____.jl]
    - replicas, see Replicas.jl
    - swap_graph, see swap_graphs.jl


Running time analysis. 

Let N denote the number of chains, P, the number of processes, and K = ceil(N/P),  
the maximum number of chains held by one process. 
Assuming the running time is dominated by communication latency and 
a constant time for the latency of each  
peer-to-peer communication, the theoretical running time is O(K). 
In practice, latency will grow as a function of P, but empirically,
this growth appears to be slow enough that for say P = N = few 1000s, 
swapping will not be the computational bottleneck.

Emphasis is on scaling laws rather than constants. For example, the current implementation 
allocates O(N) while in the case of a single 
process, it would be possible to have a no-allocation implementation. However again it is 
unlikely that this method would be the bottleneck in single-process mode.
"""
function swap_round!(swapper, replicas::Replicas, swap_graph)
    # what chains (annealing parameters) are we swapping with?
    partner_chains = [_partner_chain(swap_graph, replicas.locals[i]) for i in eachindex(replicas.locals)]

    # translate these annealing parameters (chains) into replica global indices (so that we can find machines that hold them)
    partner_replica_global_indices = permuted_get(replicas.chain_to_replica_global_indices, partner_chains)

    # assemble sufficient statistics needed to perform a swap (for vanilla PT, log likelihood and a uniform variate)
    # ... for each of my replicas
    my_swapstats = [swapstat(swapper, replicas.locals[i], partner_chains[i]) for i in eachindex(replicas.locals)]
    # ... and their partners via MPI
    partner_swapstats = transmit(entangler(replicas), my_swapstats, partner_replica_global_indices)

    # each call of _swap! performs "one half" of a swap, changing one replicas' chain field in-place
    for i in eachindex(replicas.locals)
        _swap!(swapper, replicas.locals[i], my_swapstats[i], partner_swapstats[i], partner_chains[i])
    end

    # update the distributed array linking chains to replicas
    my_replica_global_indices = my_global_indices(replicas.chain_to_replica_global_indices.entangler.load)
    permuted_set!(replicas.chain_to_replica_global_indices, chain.(replicas.locals), my_replica_global_indices)
end

"""
A 'swapper' first extracts sufficient statistics needed to perform a swap (potentially to be transmitted over network).
    In the typical case, this will be log densities before and after proposed swap (or just the likelihood with linear 
    annealing paths), and a uniform [0, 1] variate.

Then based on two sets of sufficient statistics, deterministically decide if we should swap. 
"""
swapstat(swapper, replica::Replica, partner_chain::Int) = @abstract
swap_decision(swapper, chain1::Int, stat1, chain2::Int, stat2)::Bool = @abstract


# Private low-level functions:

function _swap!(swapper, r::Replica, my_swapstat, partner_swapstat, partner_chain::Int)
    my_chain = r.chain
    if my_chain == partner_chain return nothing end

    do_swap          =  swap_decision(swapper, my_chain, my_swapstat, partner_chain, partner_swapstat)
    @assert do_swap  == swap_decision(swapper, partner_chain, partner_swapstat, my_chain, my_swapstat)

    if do_swap
        r.chain = partner_chain # NB: other "half" of the swap performed by partner
    end
end

function _partner_chain(swap_graph, r::Replica)::Int 
    my_chain = r.chain
    result            = partner_chain(swap_graph, my_chain)
    @assert my_chain == partner_chain(swap_graph, result)
    return result
end