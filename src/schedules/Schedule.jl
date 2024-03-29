"""
A partition of ``[0, 1]`` encoded by monotonically increasing grid points 
starting at zero and ending at one.
"""
struct Schedule
    """
    Monotone increasing Vector with end points at zero and one.
    """
    grids::Vector{Float64} # NB: we avoid type param here (see * below)
    
    """
    $SIGNATURES
    """
    function Schedule(grids) 
        if length(grids) == 1
            @assert grids[1] == 1.0 
            return new([1.0])
        end

        @assert issorted(grids) &&
                first(grids) == 0.0 && 
                last(grids) == 1.0 &&
                length(unique(grids)) == length(grids) "Invalid schedule: $grids"
        # (*) we get passed UnitRange in first iter, and so this 
        # would cause type incompatibility if we didn't convert
        return new(convert(Vector{Float64}, grids))
    end
end

n_chains(schedule::Schedule) = length(schedule.grids)

"""
$SIGNATURES
Create a [`Schedule`](@ref) with `n_chains` equally spaced grid points.
"""
function equally_spaced_schedule(n_chains::Int) 
    @assert n_chains ≥ 1
    if n_chains == 1 
        return Schedule([1.0])
    end
    grids = 0.0:(1.0/(n_chains-1)):1.0
    @assert length(grids) == n_chains
    return Schedule(grids)
end
