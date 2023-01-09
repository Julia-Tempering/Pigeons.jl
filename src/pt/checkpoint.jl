"""
$TYPEDSIGNATURES

Create a [`PT`](@ref) struct from a saved 
checkpoint. The path [`checkpoint_folder`] 
should point to a folder with the name 
`checkpoint` found under 
`results/all/[exec_folder]/round=x`.
"""
function PT(checkpoint_folder::String) 
    fresh_exec_folder = next_exec_folder() 
    checkpoint_symlinks(checkpoint_folder, fresh_exec_folder)
    shared, inputs = deserialize_shared_and_inputs(checkpoint_folder) # <- NB: done before replicas deserialization to load immutables
    replicas = create_replicas(shared, FromCheckpoint(checkpoint_folder))
    return PT(inputs, replicas, shared, fresh_exec_folder)
end

function write_checkpoint(pt, reduced_recorders)
    if !pt.inputs.checkpoint 
        return 
    end

    round = pt.shared.iterators.round
    checkpoint_folder = mkpath(pt.exec_folder / "round=$round/checkpoint")
    only_one_process(pt) do
        serialize(checkpoint_folder / "shared.jls", pt.shared)
        serialize(checkpoint_folder / "reduced_recorders.jls", reduced_recorders)
        # only need to save Inputs & immutables at first round
        if pt.shared.iterators.round == 1 
            serialize(checkpoint_folder / "Inputs.jls")
            serialize_immutables(pt.exec_folder / "immutables.jls")
        end
    end
    
    # each process saves its replicas
    for replica in locals(pt.replicas)
        serialize(checkpoint_folder / "replica=$(replica.replica_index).jls", replica)
    end
end

