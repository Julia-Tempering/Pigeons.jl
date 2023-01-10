"""
$SIGNATURES 


"""
function run(pt) 
    preflight_checks(pt)
    while next_round!(pt) # NB: while-loop instead of for-loop to support resuming from checkpoint
        reduced_recorders = run_one_round!(pt)
        pt = adapt(pt, reduced_recorders)
        report(pt, reduced_recorders)
        write_checkpoint(pt, reduced_recorders) 
        run_checks(pt)
    end
    return pt 
end

report(pt, reduced_recorders) = nothing # TODO

"""
$SIGNATURES 

From a [`PT`](@ref) object, run one round of 
a generalized version of Algorithm 1 in 
[Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).

Alternates between [`communicate!()`](@ref), 
which consists of any pairwise communicating 
moves and [`explore!()`], which consists in 
moves independ to each chain. 

Concrete specification of how to communicate and 
explore are specified by the field of type [`Shared`](@ref) 
contained in the provided [`PT`](@ref). 
"""
function run_one_round!(pt)
    while next_scan!(pt)
        communicate!(pt)
        explore!(pt)
    end
    return reduce_recorders!(pt.replicas)
end

"""
$SIGNATURES 

Use [`create_pair_swapper()`](@ref) and 
[`create_swap_graph`](@ref) to construct the 
inputs needed for [`swap!`](@ref).
"""
function communicate!(pt)
    tempering = pt.shared.tempering
    swapper = create_pair_swapper(tempering, pt.shared)
    graph = create_swap_graph(tempering.swap_graphs, pt.shared)
    swap!(swapper, pt.replicas, graph)
end

"""
$SIGNATURES 

Call [`regenerate!`](@ref) or [`step!()`](@ref) on 
each chain (depending if it is a reference or not 
respectively). 

Uses `@threads` to parallelize across threads. 
This is safe by the contract described in 
[`regenerate!`](@ref) and [`step!()`](@ref).
"""
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
    return PT(pt.inputs, updated_replicas, updated_shared, pt.exec_folder, reduced_recorders)
end

is_reference(chain, shared) = 
    chain in reference_chains(shared.tempering.swap_graphs, shared)
