abstract type VarReference end

"""
A variational family of reference distributions.
"""
@informal var_reference begin
    
    """
    $SIGNATURES
    Choose on which rounds/scans to activate the variational reference.
    """
    activate_var_reference(var_reference, iterators) = @abstract
    
    """
    $SIGNATURES
    Update the variational reference and the annealing path. Returns the new annealing path.
    """
    update_reference!(reduced_recorders, var_reference) = @abstract

    """
    $SIGNATURES
    Specify the recorder builders for this variational reference family.
    """
    var_reference_recorder_builders(var_reference) = @abstract
    
    """
    $SIGNATURES
    Obtain one iid sample from the reference distribution specified by the variational family.
    """
    sample_iid!(var_reference::VarReference, replica) = @abstract

    """
    $SIGNATURES
    Evaluate the log density of the variational reference at a point `x`.
    """
    (var_reference::VarReference)(state) = @abstract
end


update_path_if_needed!(path, reduced_recorders, iterators, var_reference) = 
    activate_var_reference(var_reference, iterators) ? 
        update_path_var_reference!(path, reduced_recorders, var_reference) : 
        nothing

function update_path_var_reference!(path, reduced_recorders, var_reference)
    update_reference!(reduced_recorders, var_reference)
    path = InterpolatingPath(var_reference, path.target)
end

@provides var_reference create_var_reference(inputs) = inputs.var_reference
