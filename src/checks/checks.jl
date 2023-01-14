function preflight_checks(pt)
    if pt.inputs.checked_round > 0 && !pt.inputs.checkpoint
        throw(ArgumentError("activate checkpoint when performing checks"))
    end
    if pt.inputs.checked_round < 0 || pt.inputs.checked_round > pt.inputs.n_rounds 
        throw(ArgumentError("set checked_round between 0 and n_rounds inclusively"))
    end
end

"""
Perform checks to detect software defects. 
Unable via field `checked_round` in [`Inputs`](@ref)
Currently the following checks are implemented:

- [`check_against_serial()`](@ref)
"""
function run_checks(pt)
    if pt.shared.iterators.round != pt.inputs.checked_round
        return 
    end

    only_one_process(pt) do
        #check_serialization(pt) # immutables are immutable, etc
        check_against_serial(pt)
    end
end

""" 
Run a separate, fully serial version of the PT algorithm, 
and compare the checkpoint files to ensure the two 
produce exactly the same output.
"""
function check_against_serial(pt)
    round = pt.shared.iterators.round
    parallel_checkpoint = "$(pt.exec_folder)/round=$round/checkpoint"
    
    # run a serial copy
    serial_pt_inputs = deepcopy(pt.inputs)
    serial_pt_inputs.n_rounds = round 
    serial_pt_inputs.checked_round = 0 # <- otherwise infinity loop
    serial_pt_result = pigeons(serial_pt_inputs, on = ChildProcess(n_threads = 1, wait = true))
    serial_checkpoint = "$(serial_pt_result.exec_folder)/round=$round/checkpoint"

    # compare the serialized files
    compare_checkpoints(parallel_checkpoint, serial_checkpoint)
    compare_files_checksums(
        "$(pt.exec_folder)/immutables.jls", 
        "$(serial_pt_result.exec_folder)/immutables.jls")
end

compare_checkpoints(checkpoint_folder1, checkpoint_folder2) = 
    for file in readdir(checkpoint_folder1)
        if endswith(file, ".jls")
            compare_files_checksums("$checkpoint_folder1/$file", "$checkpoint_folder2/$file")
        end
    end

function compare_files_checksums(file1, file2) 
    
    if checksum(file1) == checksum(file2)
        return 
    else
        try # TODO: clean up / make _compare_files_reproducibility more robust
            _compare_files_reproducibility(file1, file2)
        catch e 
            println("Warn: $e")
        end
        error(
            """
            detected non-reproducibility: $file1 != $file2: 
                 first: $(deserialize(file1))
                second: $(deserialize(file2))
            """
        )

    end
end

# experimental tool to help identify root cause of violation of Parallelism Invariance
function _compare_files_reproducibility(file1, file2)
    o1 = deserialize(file1)
    o2 = deserialize(file2)
    r = reproduces(o1, o2)
    println("$file1: $r")
end
