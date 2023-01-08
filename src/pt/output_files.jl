function symlink_completed_rounds_and_immutables(input_checkpoint_folder, fresh_exec_folder)
    input_exec_folder = (dirname ∘ dirname)(input_checkpoint_folder)
    symlink_with_relative_paths(input_exec_folder / "immutables.jls", fresh_exec_folder / "immutables.jls")
    round_folder_name = (basename ∘ dirname)(input_checkpoint_folder)
    round_index = parse(Int, last(Base.split(round_folder_name, "=")))
    for r = 1:round_index
        target = input_exec_folder / "round=$r"
        link = fresh_exec_folder / "round=$r"
        symlink_with_relative_paths(target, link)
    end
end

function deserialize_shared(checkpoint_folder)
    exec_folder = (dirname ∘ dirname)(checkpoint_folder)
    deserialize_immutables(exec_folder / "immutables.jls")
    return deserialize(checkpoint_folder / "shared.jls")
end