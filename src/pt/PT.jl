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
    state_init = create_state_initializer(inputs.target, inputs)
    replicas = create_replicas(shared, state_init)
    return PT(replicas, shared)
end

in_one_process(task, pt) = 
    if load(pt.replicas).my_process_index 
        task() 
    end