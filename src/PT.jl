"""
Storage involved in PT algorithms:

$FIELDS
"""
@concrete struct PT
    """
    The [`replicas`](@ref) held by this machine.
    """
    replicas

    """
    Information shared and identical across all machines.
    """
    globals
end

const LAST_COMPLETED_ROUND = -1
function PT(exec_folder, round = LAST_COMPLETED_ROUND)
    round_folder = round_folder(exec_folder, round)
    symlink_completed_rounds(exec_folder, round)
    load_immutables(exec_folder)
    replicas = create_replicas(round_folder)
    shared_pt_info = create_shared_pt_info(round_folder)
    return PT(replicas, shared_pt_info)
end

function PT(inputs::PT_Inputs)
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
    swapper = create_pair_swapper(pt.shared_pt_info)
    graph = create_swap_graph(pt.shared_pt_info)
    swap!(swapper, pt.replicas, graph)
end

function explore!(pt)
    @threads for replica in locals(pt.replicas)
        if is_reference(replica, pt.shared_pt_info)
            regenerate!(replica, shared_pt_info)
        else
            step!(replica, shared_pt_info)
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
