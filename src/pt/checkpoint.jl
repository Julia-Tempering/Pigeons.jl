"""
$SIGNATURES

Create a [`PT`](@ref) struct from a saved 
checkpoint. The path [`checkpoint_folder`] 
should point to a folder with the name 
`checkpoint` found under 
`results/all/[exec_folder]/round=x`.
"""
function PT(checkpoint_folder::String) 
    fresh_exec_folder = next_exec_folder() 
    
    exec_folder = (dirname ∘ dirname)(checkpoint_folder)
    deserialize_immutables(exec_folder / "immutables.jls")
    shared = deserialize(checkpoint_folder / "shared.jls") 
    inputs = deserialize(exec_folder / "inputs.jls")
    reduced_recorders = deserialize(checkpoint_folder / "reduced_recorders.jls")
    
    checkpoint_symlinks(checkpoint_folder, fresh_exec_folder, shared.iterators.round)
    replicas = create_replicas(inputs, shared, FromCheckpoint(checkpoint_folder))
    return PT(inputs, replicas, shared, fresh_exec_folder, reduced_recorders)
end

function write_checkpoint(pt, reduced_recorders)
    if !pt.inputs.checkpoint 
        return 
    end

    checkpoint_folder = mkpath(pt.exec_folder / "round=$(pt.shared.iterators.round)/checkpoint")    
    only_one_process(pt) do
        serialize(checkpoint_folder / "shared.jls", pt.shared)
        serialize(checkpoint_folder / "reduced_recorders.jls", reduced_recorders)
        # only need to save Inputs & immutables at first round
        if pt.shared.iterators.round == 1 
            serialize(pt.exec_folder / "inputs.jls", pt.inputs)
            serialize_immutables(pt.exec_folder / "immutables.jls")
        end
    end
    
    # each process saves its replicas
    for replica in locals(pt.replicas)
        serialize(checkpoint_folder / "replica=$(replica.replica_index).jls", replica)
    end
end

function checkpoint_symlinks(input_checkpoint_folder, fresh_exec_folder, round_index)
    input_exec_folder = (dirname ∘ dirname)(input_checkpoint_folder)
    symlink_with_relative_paths(
        input_exec_folder / "immutables.jls", 
        fresh_exec_folder / "immutables.jls")
    symlink_with_relative_paths(
            input_exec_folder / "inputs.jls", 
            fresh_exec_folder / "inputs.jls")
    round_folder_name = (basename ∘ dirname)(input_checkpoint_folder)
    for r = 1:round_index
        target = input_exec_folder / "round=$r"
        link = fresh_exec_folder / "round=$r"
        symlink_with_relative_paths(target, link)
    end
end
