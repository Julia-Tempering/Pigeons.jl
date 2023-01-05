"""
A partition of [0, 1] encoded by monotonically increasing grid points 
starting at zero and ending at one.
"""
struct Schedule{T}
    """Monotone increasing with end points at zero and one."""
    grids::T 
    """
    $TYPEDSIGNATURES
    """
    function Schedule(grids::T) where {T}
        @assert issorted(grids)
        @assert first(grids) == 0.0
        @assert last(grids) == 1.0
        new{T}(grids)
    end
end

n_chains(schedule::Schedule) = length(schedule.grids)

"""
$TYPEDSIGNATURES
Create a [`Schedule`](@ref) with `n_chains` equally spaced grid points.
"""
function Schedule(n_chains::Int) 
    @assert n_chains ≥ 2
    grids = 0.0:(1.0/(n_chains-1)):1.0
    @assert length(grids) == n_chains
    return Schedule(grids)
end

"""
$TYPEDSIGNATURES
Create a [`Schedule`](@ref) with `n_chains` grid points computed using Algorithm 2 in 
Syed et al, 2021. 
"""
Schedule(n_chains::Int, cumulativebarrier) = Schedule(updateschedule(cumulativebarrier, n_chains - 1))

"""
$TYPEDSIGNATURES
Create [`log_potentials`](@ref) from a [`path`](@ref) by interpolating the 
path at each grid point specified in the [`Schedule`](@ref).
"""
discretize(path, betas::Schedule) = [interpolate(path, beta) for beta in betas.grids]


