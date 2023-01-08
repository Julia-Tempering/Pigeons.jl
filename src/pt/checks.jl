function preflight_checks(pt)
    if pt.inputs.checked_round > 0 && !pt.inputs.checkpoint
        throw(ArgumentError("activate checkpoint when performing checks"))
    end

end

function run_checks(pt)
    if pt.iterators.round != pt.shared.inputs.checked_round
        return 
    end

    only_one_process(pt) do
        check_serialization(pt) # immutables are immutable, etc
        check_against_serial(pt)
    end
end

function check_against_serial(pt)
    round = pt.shared.iterators.round
    parallel_checkpoint = pt.shared.exec_folder / "round=$round/checkpoint"
    
    # run a serial copy
    serial_pt_result = pigeons(
        Resume(
            checkpoint_folder = parallel_checkpoint, 
            n_rounds = round), 
        ToNewProcess(n_threads = 1))
    serial_checkpoint = serial_pt_result.exec_folder / "round=$round/checkpoint"

    # compare the serialized files
    compare_checkpoints(parallel_checkpoint, serial_checkpoint)
    compare_files(
        pt.shared.exec_folder / "immutables.jls", 
        serial_pt_result.exec_folder / "immutables.jls")
end

compare_checkpoints(checkpoint_folder1, checkpoint_folder2) = 
    for file in readdir(checkpoint_folder1)
        if endswith(file, ".jls")
            compare_files(checkpoint_folder1 / file, checkpoint_folder2 / file)
        end
    end

compare_files(file1, file2) = checksum(file1) == checksum(file2)
