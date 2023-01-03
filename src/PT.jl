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

"""
$TYPEDSIGNATURES

Create a [`PT`](@ref) struct from a saved 
checkpoint. The path [`round_folder`] 
should point to a folder with a name of the 
form `round=x`. 
"""
function PT(round_folder::String)
    symlink_completed_rounds(round_folder)
    shared = deserialize_shared(round_folder) # <- should be done before replicas deserialization to load immutables
    replicas = create_replicas(shared, round_folder)
    return PT(replicas, shared)
end

function PT(inputs::Inputs)
    shared = Shared(inputs)
    replicas = create_replicas(shared)
    return PT(replicas, shared)
end

run!(pt) = 
    while next_round!(pt) # NB: not using for-loop to allow resuming from checkpoint
        reduced_recorders = run_one_round!(pt)
        pt = adapt(pt, reduced_recorders)
        report(pt)
        checkpoint(pt)
    end

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
    swapper = create_pair_swapper(pt.shared)
    graph = create_swap_graph(pt.shared)
    swap!(swapper, pt.replicas, graph)
end

function explore!(pt)
    @threads for replica in locals(pt.replicas)
        if is_reference(replica, pt.shared)
            regenerate!(replica, pt.shared)
        else
            step!(replica, pt.shared)
        end
    end
end

function checkpoint(pt)
    
end
