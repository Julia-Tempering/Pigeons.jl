"""
Abstract type for variational references.
"""
abstract type VarReference end

"""
A variational family of reference distributions. 
Implementations should also satisfy the [`log_potential`](@ref) 
contract. 
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
end


function update_path_if_needed!(path, reduced_recorders, iterators, var_reference) 
    if activate_var_reference(var_reference, iterators) 
        update_path_var_reference!(path, reduced_recorders, var_reference) 
    else 
        nothing
    end
end

function update_path_var_reference!(path, reduced_recorders, var_reference)
    update_reference!(reduced_recorders, var_reference)
    path = InterpolatingPath(var_reference, path.target)
end

function use_var_reference(inputs)
    if (inputs.n_chains_var_reference > 0)
        inputs.n_chains == 0 ? true : error("Two reference distributions have not yet been implemented.")
    else 
        return false
    end
end

"""
Create a variational reference.
"""
function create_var_reference(inputs) 
    if use_var_reference(inputs)
        var_reference = inputs.var_reference
    else 
       var_reference = NoVarReference()
    end 
end
