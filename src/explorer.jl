@informal explorer begin
    regenerate!(explorer, replica, shared) = @abstract
    step!(explorer, replica, shared) = @abstract 
end

@provides explorer create_explorer(inference_problem) = @abstract 
@provides explorer adapt(explorer, reduced_recorders, shared) = @abstract 

create_explorers(inputs) = create_explorers(inputs.inference_problem)
