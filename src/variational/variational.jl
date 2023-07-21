"""
A variational family of reference distributions. 
Implementations should also satisfy the [`log_potential`](@ref) 
contract and [`sample_iid!()`](@ref). 
"""
@informal variational begin
    
    """
    $SIGNATURES
    Choose on which rounds/scans to activate the variational reference.
    """
    activate_variational(variational, iterators) = false
    
    """
    $SIGNATURES
    Update the variational reference and the annealing path. Returns the new annealing path.
    """
    update_reference!(reduced_recorders, variational, state) = nothing

    """
    $SIGNATURES
    Specify the recorder builders for this variational reference family.
    """
    variational_recorder_builders(variational) = []
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

