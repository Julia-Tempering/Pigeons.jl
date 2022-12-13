"""
A continuum of [`log_potential`](@ref)'s interpolating between two end-points.

Convention: the continuum is indexed on [0, 1] 
"""
@informal path begin
    """
    $TYPEDSIGNATURES
    Returns a [`log_potential`](@ref).
    """
    interpolate(path, beta) = @abstract
end

