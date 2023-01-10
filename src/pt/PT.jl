"""
Storage involved in PT algorithms:

$FIELDS
"""
@concrete struct PT

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
    Path to a directory shared by all MPI processes, 
    or nothing if a completely in-memory algorithm is used. 
    """
    exec_folder::Union{String, Nothing}
end

"""
$SIGNATURES
"""
function PT(inputs::Inputs)
    shared = Shared(inputs)
    state_init = create_state_initializer(inputs.target, inputs)
    replicas = create_replicas(inputs, shared, state_init)
    return PT(inputs, replicas, shared, next_exec_folder())
end

Base.show(io::IO, pt::PT) = # contract: should give valid julia expression creating an equivalent object
    pt.shared.iterators.round == 0 ?
        print(io, "PT($(pt.inputs))") :
        print(io, "PT(\"$(pt.exec_folder)/round=$(pt.shared.iterators.round)/checkpoint\")")

"""
$SIGNATURES 

A task that should be ran on only one of the MPI processes. 
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