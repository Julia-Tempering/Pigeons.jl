"""
$FIELDS
"""
struct Schedule{T}
    """Monotone increasing with end points at zero and one."""
    grids::T 
    function Schedule(grids::T) where {T}
        @assert issorted(grids)
        @assert first(grids) == 0.0
        @assert last(grids) == 1.0
        new{T}(grids)
    end
end

"""
$TYPEDSIGNATURES
"""
function equally_spaced(n_chains::Int)
    grids = 0.0:(1.0/(n_chains-1)):1.0
    @assert length(grids) == n_chains
    return Schedule(grids)
end

"""
$TYPEDSIGNATURES
"""
discretize(path, betas::Schedule) = [interpolate(path, beta) for beta in betas.grids]