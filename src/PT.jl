

mutable struct PT_Iterators
    """
    Index of the PT adaptation *round*, as defined in 
    [Algorithm 4 of Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
    """
    round::Int 

    """
    Number of (exploration, communication) pairs performed 
    so far, corresponds to ``n`` in 
    [Algorithm 1 of Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
    Round ``i`` typically performs ``2^i`` scans. 
    """
    scan::Int
end

struct PT_Inputs{I}
    inference_problem::I
    rng::SplittableRandom
end

"""
All the storage involved in PT algorithms:

$FIELDS
"""
struct PT{R, S}
    """
    The [`replicas`](@ref) held by this machine.
    """
    replicas::R

    """
    Information shared and identical across all machines.
    """
    shared::S
end

const LAST_COMPLETED_ROUND = -1
function PT(exec_folder, round = LAST_COMPLETED_ROUND)
    round_folder = round_folder(exec_folder, round)
    symlink_completed_rounds(exec_folder, round)
    load_immutables(exec_folder)
    replicas = create_replicas(round_folder)
    shared = create_shared(round_folder)
    return PT(replicas, shared)
end

function PT(inputs)
    replicas = create_replicas(inputs)
    etc
end



run!(pt) = 
    while next_round!(pt) # NB: not using for-loop to allow resume from checkpoint
        reduced_recorders = run_one_round!(pt)
        pt = adapt(pt, reduced_recorders)
        report(pt)
        checkpoint(pt)
    end

function run_one_round!(pt)
    while next_scan!(pt)
        communicate!(pt)
        explore!(pt)
    end
    return reduce_recorders!(pt.replicas)
end

function communicate!(pt)
    swapper = create_pair_swapper(pt.shared)
    graph = create_swap_graph(pt.shared)
    swap!(swapper, pt.replicas, graph)
end

function explore!(pt)
    @threads for replica in locals(pt.replicas)
        if is_reference(replica, pt.shared)
            regenerate!(replica, shared)
        else
            step!(replica, shared)
        end
    end
end


function checkpoint(pt)
    #= 

    Need to decide: if resume check point, do we get a 
    new exec folder? -> yes (complications with partially written folder, ec)

    Check-pointing should be agnostic to MPI setup.

    NOTE: due to file based recorders, much easier to 
    implement across rounds than in the middle of a round.
    
    =#
end
