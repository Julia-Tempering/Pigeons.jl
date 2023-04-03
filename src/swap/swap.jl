"""
$SIGNATURES

Single process, non-allocating `swap!` implementation. 
"""
function swap!(pair_swapper, replicas::Vector{R}, swap_graph) where R
    @assert sorted(replicas)
    for my_chain in eachindex(replicas)
        my_replica = replicas[my_chain]
        partner_chain = checked_partner_chain(swap_graph, my_chain)
        if partner_chain >= my_chain # ensures that the swap is only done once per pair
            partner_replica = replicas[partner_chain]
            @assert partner_replica.chain == partner_chain
            my_swap_stat      = swap_stat(pair_swapper, my_replica, partner_chain)
            partner_swap_stat = partner_chain == my_chain ? 
                my_swap_stat :
                swap_stat(pair_swapper, partner_replica, my_chain)
            _swap!(pair_swapper, my_replica,      my_swap_stat,      partner_swap_stat, partner_chain, swap_graph)
            if partner_chain != my_chain
            _swap!(pair_swapper, partner_replica, partner_swap_stat, my_swap_stat,      my_chain, swap_graph)
            end
        end
    end
    # "re-sort": do not need to sort from scratch, just need swaps
    resort_replicas!(replicas)
end

function resort_replicas!(replicas)
    for my_chain in eachindex(replicas)
        my_replica = replicas[my_chain]
        if my_replica.chain != my_chain
            partner_chain = my_replica.chain
            partner_replica = replicas[partner_chain]
            @assert partner_replica.chain == my_chain
            replicas[my_chain]      = partner_replica
            replicas[partner_chain] = my_replica
        end
    end
end

# when reloading the vector-backed replicas from checkpoint, need to sort from scratch
sort_replicas!(replicas) = sort!(replicas, by = r -> r.chain)

function sorted(replicas) 
    for i in eachindex(replicas)
        if i != replicas[i].chain
            return false
        end
    end
    return true
end

"""
$SIGNATURES

Entangled MPI `swap!` implementation.

This implementation is designed to support distributed PT with the following guarantees

- The running time is independent of the size of the state space 
      ('swapping annealing parameters rather than states')
- The output is identical no matter how many MPI processes are used. In particular, 
      this means that we can check correctness by comparing to the serial, single-process version.
- Scalability to 1000s of processes communicating over MPI (see details below).
- The same function can be used when a single process is used and MPI is not available.
- Flexibility to extend PT to e.g. networks of targets and general paths.

Running time analysis:

Let ``N`` denote the number of chains, ``P``, the number of processes, and ``K = \\text{ceil}(N/P)``,  
the maximum number of chains held by one process. 
Assuming the running time is dominated by communication latency and 
a constant time for the latency of each  
peer-to-peer communication, the theoretical running time is ``O(K)``. 
In practice, latency will grow as a function of ``P``, but empirically,
this growth appears to be slow enough that for say ``P = N =`` a few 1000s, 
swapping will not be the computational bottleneck.
"""
function swap!(pair_swapper, replicas::EntangledReplicas, swap_graph)
    # what chains (annealing parameters) are we swapping with?
    partner_chains = [checked_partner_chain(swap_graph, replicas.locals[i].chain) for i in eachindex(replicas.locals)]

    # translate these annealing parameters (chains) into replica global indices (so that we can find machines that hold them)
    partner_replica_global_indices = permuted_get(replicas.chain_to_replica_global_indices, partner_chains)

    # assemble sufficient statistics needed to perform a swap (for vanilla PT, log likelihood and a uniform variate)
    # ... for each of my replicas
    my_swap_stats = [swap_stat(pair_swapper, replicas.locals[i], partner_chains[i]) for i in eachindex(replicas.locals)]
    # ... and their partners via MPI
    partner_swap_stats = transmit(entangler(replicas), my_swap_stats, partner_replica_global_indices)

    # each call of _swap! performs "one half" of a swap, changing one replicas' chain field in-place
    lb = load(replicas)
    for i in eachindex(replicas.locals)
        @assert find_global_index(lb, i) === replicas.locals[i].replica_index
        _swap!(pair_swapper, replicas.locals[i], my_swap_stats[i], partner_swap_stats[i], partner_chains[i], swap_graph)
    end

    # update the distributed array mapping chains to replicas
    my_replica_global_indices = my_global_indices(replicas.chain_to_replica_global_indices.entangler.load)
    permuted_set!(replicas.chain_to_replica_global_indices, chain.(replicas.locals), my_replica_global_indices)
end

# Private low-level functions shared by all implementations

function _swap!(pair_swapper, r::Replica, my_swap_stat, partner_swap_stat, partner_chain::Int, swap_graph)
    my_chain = r.chain

    # keep track of index process even if not performing swap
    record_if_requested!(r.recorders, :index_process, (r.replica_index, r.chain))
    record_if_requested!(r.recorders, :round_trip, (is_reference(swap_graph, r.chain), is_target(swap_graph, r.chain)))

    if my_chain == partner_chain return nothing end

    do_swap          =  swap_decision(pair_swapper, my_chain, my_swap_stat, partner_chain, partner_swap_stat)
    @assert do_swap  == swap_decision(pair_swapper, partner_chain, partner_swap_stat, my_chain, my_swap_stat)

    # record statistics on this swap
    if my_chain < partner_chain
        record_swap_stats!(pair_swapper, r.recorders, my_chain, my_swap_stat, partner_chain, partner_swap_stat)
    end

    apply_swap!(pair_swapper, partner_chain, do_swap, r, my_swap_stat)
end

function checked_partner_chain(swap_graph, my_chain::Int)::Int 
    result            = partner_chain(swap_graph, my_chain)
    @assert my_chain == partner_chain(swap_graph, result)
    return result
end