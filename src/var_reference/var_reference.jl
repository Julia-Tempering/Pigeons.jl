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
    update_path!(path, iterators, var_reference) = @abstract

    """
    $SIGNATURES
    Specify the recorder builders for this variational reference family.
    """
    var_reference_recorder_builders(var_reference) = @abstract
    
    """
    $SIGNATURES
    Obtain one iid sample from the reference distribution specified by the variational family.
    """
    sample_iid!(var_reference) = @abstract
end


function use_var_reference(inputs)
    if (inputs.n_chains_var_reference > 0)
        inputs.n_chains == 0 ? true : error("Two reference distributions have not yet been implemented.")
    else 
        return false
    end
end

@provides var_reference function create_var_reference(inputs) 
    if use_var_reference(inputs)
        var_reference = GaussianReference() # default to Gaussian for now
    else 
       var_reference = NoVarReference()
    end 
end
