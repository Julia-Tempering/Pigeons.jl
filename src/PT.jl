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
    shared
end

function PT(inputs::Inputs)
    shared = Shared(inputs)
    replicas = create_replicas(shared, create_state_initializer(inputs))
    return PT(replicas, shared)
end

"""
$TYPEDSIGNATURES

Create a [`PT`](@ref) struct from a saved 
checkpoint. The path [`round_folder`] 
should point to a folder with a name of the 
form `round=x`. 
"""
function PT(round_folder::String)
    symlink_completed_rounds_and_immutables(round_folder)
    shared = deserialize_shared(round_folder) # <- should be done before replicas deserialization to load immutables
    replicas = create_replicas(shared, FromCheckpoint(round_folder))
    return PT(replicas, shared)
end

function checkpoint(pt)
    if load(pt.replicas).my_process_index == 1
        # process #1 saves the shared state
        serialize(round_folder(pt.iterators.round) / "shared.jls")
        # process #1 saves immutables, but only during first round
        if pt.iterators.round == 1 
            serialize_immutables(exec_folder() / "immutables.jls")
        end
        #=
        TODO: In first two rounds, save also for the second process,
            and compare shared and immutables to make sure they 
            respect their contracts. 
        =#
    end
    
    # each process saves its replicas
    for replica in locals(pt.replicas)
        serialize(round_folder(pt.iterators.round) / "replica=$(replica.replica_index)")
    end
end

