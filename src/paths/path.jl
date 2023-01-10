"""
A continuum of [`log_potential`](@ref)'s interpolating between two end-points.
More precisely, a mapping from [0, 1] to the space of probability distributions.

The main use of this interface is to pass it to [`discretize()`](@ref).
"""
@informal path begin
    """
    $SIGNATURES
    Returns the [`log_potential`](@ref) at point `beta` in the [`path`](@ref)
    """
    interpolate(path, beta) = @abstract
end

""" 
$SIGNATURES

Default method used to construct paths. 
Assumes by default that target is a [`log_potential`](@ref) and 
construct the standard annealing between the target and the [`log_potential`](@ref) 
constucted by [`create_reference()`](@ref).
""" 
@provides path create_path(target, inputs::Inputs) = create_path(create_reference(target, inputs), target)

""" 
$SIGNATURES 

In this case, the target is already a [`path`](@ref), so return it. 
"""
create_path(target::ScaledPrecisionNormalPath, inputs::Inputs) = target

