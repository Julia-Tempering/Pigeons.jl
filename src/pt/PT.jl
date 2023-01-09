"""
Storage involved in PT algorithms:

$FIELDS
"""
@concrete struct PT

    inputs

    """
    The [`replicas`](@ref) held by this machine.
    """
    replicas

    """
    Information shared and identical across all machines.
    """
    shared

    exec_folder
end

function PT(inputs::Inputs)
    shared = Shared(inputs)
    state_init = create_state_initializer(inputs.target, inputs)
    replicas = create_replicas(inputs, shared, state_init)
    return PT(inputs, replicas, shared, next_exec_folder())
end

Base.show(io::IO, pt::PT) = 
    print(io, "PT(exec_folder = $(pt.exec_folder), n_MPI_processes = $(load(pt.replicas).n_processes))")

only_one_process(task, pt) = 
    if load(pt.replicas).my_process_index == 1
        task() 
    end