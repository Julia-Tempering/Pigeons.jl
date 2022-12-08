"""
A continuum of log_potential's interpolating between two end-points.

Convention: the continuum is indexed on [0, 1] 
"""

interpolate(path, beta) = @abstract

# move that stuff


struct Schedule{T}
    grids::T 
    function Schedule(grids::T) where {T}
        @assert issorted(grids)
        @assert first(grids) == 0.0
        @assert last(grids) == 1.0
        new{T}(grids)
    end
end
function equally_spaced(n_chains::Int)
    grids = 0.0:(1.0/(n_chains-1)):1.0
    @assert length(grids) == n_chains
    return Schedule(grids)
end

discretize(path, betas::Schedule) = [interpolate(path, beta) for beta in betas.grids]
