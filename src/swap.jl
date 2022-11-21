
swap_decision(swapper, chain1::Int, stat1, chain2::Int, stat2)::Bool = @abstract
swapstat(swapper, replica::Replica, partner_chain::Int) = @abstract

function swap_round!(swapper, replicas::Replicas, swap_graph)
    # what chains (annealing parameters) are we swapping with?
    partner_chains = [_partner_chain(swap_graph, replicas.locals[i]) for i in eachindex(replicas.locals)]

    # translate these annealing parameters (chains) into replica global indices (so that we can find machines that hold them)
    partner_replica_global_indices = permuted_get(replicas.chain_to_replica_global_indices, partner_chains)

    # assemble sufficient statistics needed to perform a swap (log densities and uniform variates with standard swaps)
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