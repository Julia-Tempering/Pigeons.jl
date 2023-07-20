"""
Abstract type for variational references.
"""
abstract type VarReference end

struct NoVarReference <: VarReference end 

activate_variational(::NoVarReference, _) = false
update_path!(path, _, ::NoVarReference) = nothing
variational_recorder_builders(::NoVarReference) = []

"""
A variational family of reference distributions. 
Implementations should also satisfy the [`log_potential`](@ref) 
contract. 
"""
@informal variational begin
    
    """
    $SIGNATURES
    Choose on which rounds/scans to activate the variational reference.
    """
    activate_variational(variational, iterators) = @abstract
    
    """
    $SIGNATURES
    Update the variational reference and the annealing path. Returns the new annealing path.
    """
    update_reference!(reduced_recorders, variational, state) = @abstract

    """
    $SIGNATURES
    Specify the recorder builders for this variational reference family.
    """
    variational_recorder_builders(variational) = @abstract
    
    """
    $SIGNATURES
    Obtain one iid sample from the reference distribution specified by the variational family.
    """
    sample_iid!(variational::VarReference, replica, shared) = @abstract
end


function update_path_if_needed(path, reduced_recorders, iterators, variational, state) 
    if activate_variational(variational, iterators) 
        return update_path_variational(path, reduced_recorders, variational, state) 
    else 
        return path
    end
end

function update_path_variational(path, reduced_recorders, variational, state)
    update_reference!(reduced_recorders, variational, state)
    path = InterpolatingPath(variational, path.target)
    return path
end

create_variational(inputs) = inputs.variational
