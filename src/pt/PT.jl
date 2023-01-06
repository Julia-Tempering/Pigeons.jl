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
    state_init = create_state_initializer(inputs.inference_problem, inputs)
    replicas = create_replicas(shared, state_init)
    return PT(replicas, shared)
end

"""
$TYPEDSIGNATURES

Create a [`PT`](@ref) struct from a saved 
checkpoint. The path [`checkpoint_folder`] 
should point to a folder with the name 
`checkpoint` found under 
`results/all/[exec_folder]/round=x`.
"""
function PT(checkpoint_folder::String)
    symlink_completed_rounds_and_immutables(checkpoint_folder)
    shared = deserialize_shared(checkpoint_folder) # <- should be done before replicas deserialization to load immutables
    replicas = create_replicas(shared, FromCheckpoint(checkpoint_folder))
    return PT(replicas, shared)
end

function checkpoint(pt)
    round = pt.shared.iterators.round
    checkpoint_folder = exec_subfolder("round=$round/checkpoint")
    if load(pt.replicas).my_process_index == 1
        # process #1 saves the shared state
        serialize(checkpoint_folder / "shared.jls", pt.shared)
        # process #1 saves immutables, but only during first round
        if pt.shared.iterators.round == 1 
            serialize_immutables(exec_folder() / "immutables.jls")
        end
        #=
        TODO: In first two rounds, save also for the second process,
            and compare shared and immutables to make sure they 
            respect their contracts. 
        .. or better(?), share hashes?
        =#
    end
    
    # each process saves its replicas
    for replica in locals(pt.replicas)
        serialize(checkpoint_folder / "replica=$(replica.replica_index).jls", replica)
    end
end

