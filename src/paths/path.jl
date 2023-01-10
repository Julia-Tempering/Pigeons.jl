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

