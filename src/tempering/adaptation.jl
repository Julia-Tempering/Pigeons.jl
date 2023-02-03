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
            reduced_recorders, 
            n_chains(old_schedule)), 
        old_schedule, 
        new_schedule_n_chains
    )

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

@concrete struct LocalBarrier
    cumulativebarrier
end
(barrier::LocalBarrier)(beta) = Interpolations.gradient(cumulativebarrier, beta)[1]

is_intensity(x::AbstractArray{T}) where {T} = all(≥(zero(T)), x)

function optimal_schedule_generator(intensity::AbstractVector, old_schedule::AbstractVector, nudged::Bool = false)
    @assert length(old_schedule) == length(intensity) + 1 
    @assert is_intensity(intensity)
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

communication_barriers(reduced_recorders, schedule::Schedule) =
    communication_barriers(
        rejections(
            reduced_recorders, 
            n_chains(schedule)), 
        schedule.grids
    )

function rejections(reduced_recorders, n_chains)
    accept_recorder = reduced_recorders.swap_acceptance_pr
    max_index = n_chains - 1
                        # we use defaults since in the first round, not all swaps are attempted, use 0.5 for missing entries
    return [1.0 - value_with_default(accept_recorder, (i, i+1), 0.5) for i in 1:max_index] 
end
