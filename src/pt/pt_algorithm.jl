function run!(pt) 
    preflight_checks(pt)
    while next_round!(pt) # NB: not using for-loop to allow resuming from checkpoint
        reduced_recorders = run_one_round!(pt)
        pt = adapt(pt, reduced_recorders)
        report(pt, reduced_recorders)
        write_checkpoint(pt, reduced_recorders) 
        run_checks(pt)
    end
end

report(pt, reduced_recorders) = nothing # TODO

#= 
    TODO: run some tests in the first few rounds? 
    e.g. reloading checkpoint, etc
    with an option to disable but done by default 
=#

function run_one_round!(pt)
    while next_scan!(pt)
        communicate!(pt)
        explore!(pt)
    end
    return reduce_recorders!(pt.replicas)
end

function communicate!(pt)
    tempering = pt.shared.tempering
    swapper = create_pair_swapper(tempering, pt.shared)
    graph = create_swap_graph(tempering.swap_graphs, pt.shared)
    swap!(swapper, pt.replicas, graph)
end

function explore!(pt)
    explorer = pt.shared.explorer
    @threads for replica in locals(pt.replicas)
        if is_reference(replica.chain, pt.shared)
            regenerate!(explorer, replica, pt.shared)
        else
            step!(explorer, replica, pt.shared)
        end
    end
end

function adapt(pt, reduced_recorders)
    updated_tempering = adapt_tempering(pt.shared.tempering, reduced_recorders)
    updated_explorer = adapt_explorer(pt.shared.explorer, reduced_recorders, updated_tempering)
    updated_shared = Shared(
        pt.shared.iterators, 
        updated_tempering, 
        updated_explorer)
    updated_replicas = pt.replicas # TODO: adapt too? e.g. assign to closest from previous, leveraging checkpoints?
    set_shared(updated_replicas, updated_shared)
    return PT(updated_replicas, updated_shared, pt.exec_folder)
end

is_reference(chain, shared) = 
    chain in reference_chains(shared.tempering.swap_graphs, shared)
