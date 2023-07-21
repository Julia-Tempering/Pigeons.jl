"""
Storage involved in PT algorithms:

$FIELDS
"""
@auto struct PT

    """
    The user-provided [`Inputs`](@ref) that determine 
    the execution of a PT algorithm. 
    """
    inputs

    """
    The [`replicas`](@ref) held by this machine.
    """
    replicas

    """
    Information shared across all machines, updated between 
    rounds. 
    """
    shared

    """
    Either a path to a folder shared by all processes, 
    which is used to save information to disk (checkpoints, samples etc);
    or nothing if a completely in-memory algorithm is used. 
    """
    exec_folder::Union{String, Nothing}
    
    """
    [`recorders`](@ref) from the last round, or empty 
    [`recorders`](@ref). 
    """
    reduced_recorders
end

"""
$SIGNATURES

Create a PT struct from provided [`Inputs`](@ref). 
Optionally, provide a specific `exec_folder` path (`AbstractString`), 
if not one will be created via [`next_exec_folder()`](@ref).
"""
function PT(inputs::Inputs; exec_folder = use_auto_exec_folder)
    shared = Shared(inputs)
    replicas = create_replicas(inputs, shared)
    exec_folder = pt_exec_folder(inputs.checkpoint, exec_folder)
    return PT(inputs, replicas, shared, exec_folder, create_recorders(inputs, shared))
end

pt_exec_folder(use_checkpoint, specified_exec_folder) = 
    if use_checkpoint
        if specified_exec_folder == use_auto_exec_folder
            next_exec_folder()
        else
            specified_exec_folder
        end
    else
        nothing 
    end

Base.show(io::IO, pt::PT) = 
    if pt.shared.iterators.round == 0 || !pt.inputs.checkpoint 
        print(io, "PT(checkpoint = false, ...)")
    else
        print(io, "PT(\"$(pt.exec_folder)\")")
    end


"""
$SIGNATURES 

A task that should be ran on only one of the processes. 
Using the `do .. end` syntax, this can be used as:

```
only_one_process(pt) do 
    ...
end
```
"""
only_one_process(task, pt) = 
    if load(pt.replicas).my_process_index == 1
        task() 
    end

only_one_process_println(pt, arguments) = 
    only_one_process(pt) do 
        println(arguments)
    end