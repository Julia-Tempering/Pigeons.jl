""" 
$SIGNATURES 

Return an optimal [`Schedule`](@ref) based on statistics from a previous round. 
"""
optimal_schedule(
        intensity::AbstractVector, 
        old_schedule::Schedule, 
        new_schedule_n_chains::Int) = 
    Schedule(
        optimal_schedule(
            intensity, 
            old_schedule.grids, 
            new_schedule_n_chains))

optimal_schedule(
        reduced_recorders, 
        old_schedule::Schedule, 
        new_schedule_n_chains::Int) = 
    optimal_schedule(
        rejections(
            reduced_recorders, n_chains(old_schedule)), 
        old_schedule, 
        new_schedule_n_chains
    )

function optimal_schedule(reduced_recorders, old_schedule::Schedule, chain_indices::AbstractVector)
    optimal_schedule(
        rejections(reduced_recorders, chain_indices),
        old_schedule,
        length(chain_indices)+1
    )
end

optimal_schedule(intensity_or_recorders, old_schedule::Schedule) = 
    optimal_schedule(
        intensity_or_recorders, 
        old_schedule, 
        n_chains(old_schedule)
    )

"""
$SIGNATURES

Compute the local communication barrier and cumulative barrier functions from the 
`intensity` rates (i.e. rejection rates in the context of Parallel Tempering) and 
the current annealing `schedule`. The estimation of the barriers 
is based on Fritsch-Carlson monotonic interpolation.

Returns a `NamedTuple` with fields:

- `localbarrier`
- `cumulativebarrier`
- `globalbarrier`
"""
function communication_barriers(intensity::AbstractVector, schedule::AbstractVector)
    @assert length(schedule) == length(intensity) + 1
    @assert is_intensity(intensity)
    x = schedule
    y = [0; cumsum(intensity)]
    cumulativebarrier = Interpolations.interpolate(x, y, FritschCarlsonMonotonicInterpolation())
    localbarrier = LocalBarrier(cumulativebarrier)
    globalbarrier = sum(intensity)
    return (; localbarrier, cumulativebarrier, globalbarrier)
end

@auto struct LocalBarrier
    cumulativebarrier
end
(barrier::LocalBarrier)(beta) = Interpolations.gradient(barrier.cumulativebarrier, beta)[1]

is_intensity(x::AbstractArray{T}) where {T} = all(≥(zero(T)), x)

function optimal_schedule_generator(intensity::AbstractVector, old_schedule::AbstractVector, nudged::Bool = false)
    @assert length(old_schedule) == length(intensity) + 1 
    @assert is_intensity(intensity) "Bad intensities: $intensity"
    x = [0; cumsum(intensity)]
    y = old_schedule 
    norm = last(x) 
    x = x ./ norm 
    if length(unique(x)) != length(x) # some intensities are zero or so low they underflow after normalization
        @assert !nudged # avoid infinity loop
        return optimal_schedule_generator(intensity .+ 1e-6, old_schedule, true)
    end
    return Interpolations.interpolate(x, y, FritschCarlsonMonotonicInterpolation()) 
end

function optimal_schedule(intensity::AbstractVector, old_schedule::AbstractVector, new_schedule_n_chains::Int)
    generator = optimal_schedule_generator(intensity, old_schedule)
    step_size = 1.0 / (new_schedule_n_chains - 1)
    uniform_grid = step_size:step_size:(1.0-step_size)
    return [0.0; generator.(uniform_grid); 1.0]
end

communication_barriers(reduced_recorders, schedule::Schedule, chain_indices::AbstractVector) =
    communication_barriers(
        rejections(
            reduced_recorders, 
            chain_indices), 
        schedule.grids
    )

rejections(reduced_recorders, n_chains::Int) =
    rejections(key_subset, 1:(n_chains-1))

""" Similar to above except that instead of the number of chains, 
provide the full vector of chain indices.
Note that `chain_indices` starts at the reference and ends at the chain *one before* the target. """
function rejections(reduced_recorders, chain_indices::AbstractVector) 
    accept_recorder = reduced_recorders.swap_acceptance_pr
    return [1.0 - value_with_default(accept_recorder, (i, i+1), 0.5) for i in chain_indices]
end