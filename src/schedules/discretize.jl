"""
$TYPEDSIGNATURES
Create [`log_potentials`](@ref) from a [`path`](@ref) by interpolating the 
path at each grid point specified in the [`Schedule`](@ref).
"""
discretize(path, betas::Schedule) = 
    [interpolate(path, beta) for beta in betas.grids]


