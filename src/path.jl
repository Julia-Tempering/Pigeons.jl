"""
A continuum of [`log_potential`](@ref)'s interpolating between two end-points.
More precisely, a mapping from [0, 1] to the space of probability distributions. 
"""
@informal path begin
    """
    $TYPEDSIGNATURES
    Returns the [`log_potential`](@ref) at point `beta` in the [`path`](@ref)
    """
    interpolate(path, beta) = @abstract
end

