"""
$SIGNATURES

Create a [`PT`](@ref) struct from a saved 
checkpoint. The input `source_exec_folder`
should point to a folder of the form 
`results/all/[exec_folder]`.

The checkpoint carries all the information stored in 
a [`PT`](@ref) struct. It is possible for an MPI-based 
execution to load a checkpoint written by a single-process 
execution and vice versa.

A new unique folder will be created with symlinks to 
the source one, so that e.g. running more rounds of 
PT will results in a new space-efficient checkpoint 
containing all the information for the new run.
"""
function PT(source_exec_folder::AbstractString; 
            round = latest_checkpoint_folder(source_exec_folder),
            exec_folder = use_auto_exec_folder)  
    if round == 0
        error("no checkpoint is available yet for $source_exec_folder")
    elseif round < 0
        throw(ArgumentError("round should be positive"))
    end
    
    if source_exec_folder == "results/latest" || source_exec_folder == "results/latest/"
        resolved = readlink("results/latest")
        source_exec_folder = "results/$resolved"
    end 

    exec_folder = pt_exec_folder(true, exec_folder)
    checkpoint_folder = "$source_exec_folder/round=$round/checkpoint"

    deserialize_immutables!("$source_exec_folder/immutables.jls")
    shared = deserialize("$checkpoint_folder/shared.jls") 
    inputs = deserialize("$source_exec_folder/inputs.jls")
    reduced_recorders = deserialize("$checkpoint_folder/reduced_recorders.jls")

    replicas = create_replicas(inputs, shared, FromCheckpoint(checkpoint_folder))
    result = PT(inputs, replicas, shared, exec_folder, reduced_recorders)
    
    only_one_process(result) do
        checkpoint_symlinks!(checkpoint_folder, exec_folder, round)
    end
    
    return result
end

"""$SIGNATURES"""
function latest_checkpoint_folder(exec_folder)
    try
        deserialize_immutables!("$exec_folder/immutables.jls")
        inputs = deserialize("$exec_folder/inputs.jls")
        for r in reverse(1:inputs.n_rounds)
            checkpoint_folder = "$exec_folder/round=$r/checkpoint"
            if is_finished(checkpoint_folder, inputs)
                return r
            end
        end
    catch e 
    end
    return 0
end

"""
$SIGNATURES 

Is the provided path to a checkpoint folder complete? 
I.e. check in the .signal subfolder that all MPI processes have 
signaled that they are done.
"""
function is_finished(checkpoint_folder::AbstractString, inputs)    
    signal_folder = "$checkpoint_folder/.signal"
    if !isdir(signal_folder)
        return false
    end
    n_complete = 0 
    for file in readdir(signal_folder)
        if startswith(file, "finished_replica")
            n_complete += 1
        end
    end
    return n_complete == n_chains(inputs)
end

""" 
$SIGNATURES 

If `pt.inputs.checkpoint == true`, save a checkpoint under 
`[pt.exec_folder]/[unique folder]/round=[x]/checkpoint`. 

By default, `pt.exec_folder` is `results/all/[unique folder]`.

In an MPI context, each MPI process will write its local replicas, 
while only one of the MPI processes will write the [`Shared`](@ref) 
and reduced [`recorders`](@ref) data. Moreover, only one MPI process will 
write once at the first round the [`Inputs`](@ref) data. 

In cases where the sampled model contains large immutable data, consider using 
`Immutable`'s to save disk space (Immutables will be written only by 
one MPI process at the first round). 
"""
function write_checkpoint(pt)
    if !pt.inputs.checkpoint 
        return 
    end
    checkpoint_folder = mkpath("$(pt.exec_folder)/round=$(pt.shared.iterators.round)/checkpoint")    

    # beginning of serialization session 
    flush_immutables!()    

    # each process saves its replicas
    for replica in locals(pt.replicas)
        serialize("$checkpoint_folder/replica=$(replica.replica_index).jls", replica)
    end
    
    only_one_process(pt) do
        serialize("$checkpoint_folder/shared.jls", pt.shared)
        serialize("$checkpoint_folder/reduced_recorders.jls", pt.reduced_recorders)
        # only need to save Inputs & immutables at first round
        if pt.shared.iterators.round == 1 
            serialize("$(pt.exec_folder)/inputs.jls", pt.inputs)
            # this needs to be last!
            if !isfile("$(pt.exec_folder)/immutables.jls") # if running via submission, this is written for us 
                serialize_immutables("$(pt.exec_folder)/immutables.jls")
            end
        end
    end

    # end of serialization session
    flush_immutables!()

    # signal that we are done
    for replica in locals(pt.replicas)
        signal_folder = mkpath("$checkpoint_folder/.signal")
        touch("$signal_folder/finished_replica=$(replica.replica_index)")
    end
end

function checkpoint_symlinks!(input_checkpoint_folder, exec_folder, round_index, same_inputs = true)
    input_exec_folder = (dirname ∘ dirname)(input_checkpoint_folder)
    if !isfile("$exec_folder/immutables.jls") # immutables.jls can already exist when it gets created by subnmission_utils already
        safelink(
            "$input_exec_folder/immutables.jls", 
            "$exec_folder/immutables.jls")
    end
    if same_inputs    
        safelink(
            "$input_exec_folder/inputs.jls", 
            "$exec_folder/inputs.jls")
    end
    for r = 1:round_index
        target = "$input_exec_folder/round=$r"
        link = "$exec_folder/round=$r"
        safelink(target, link)
    end
end

function increment_n_rounds!(pt::PT, increment::Int)
    pt.inputs.n_rounds += increment 
    new_exec_folder = pt.exec_folder 
    if pt.exec_folder !== nothing 
        new_exec_folder = increment_n_rounds!(pt.exec_folder, increment)
    end
    return PT(pt.inputs, pt.replicas, pt.shared, new_exec_folder, pt.reduced_recorders)
end

function increment_n_rounds!(source_exec_folder::String, increment::Int) 
    if source_exec_folder == "results/latest" || source_exec_folder == "results/latest/"
        resolved = readlink("results/latest")
        source_exec_folder = "results/$resolved"
    end 
    round = latest_checkpoint_folder(source_exec_folder)
    exec_folder = pt_exec_folder(true, use_auto_exec_folder)
    checkpoint_folder = "$source_exec_folder/round=$round/checkpoint"
    deserialize_immutables!("$source_exec_folder/immutables.jls")
    inputs = deserialize("$source_exec_folder/inputs.jls")
    inputs.n_rounds += increment
    checkpoint_symlinks!(checkpoint_folder, exec_folder, round, false)
    serialize("$exec_folder/inputs.jls", inputs) 
    return exec_folder
end
