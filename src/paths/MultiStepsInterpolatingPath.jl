# Paths based on interpolating an arbitrary list of log_potential's

@auto struct MultiStepsInterpolatingPath
    knots
    interpolator
end

"""
$SIGNATURES

Given a list of [`log_potential`](@ref) ("knots"), 
return a [`path`](@ref) interpolating between them. 

By default, the `interpolator` is a `LinearInterpolator`, i.e. 
standard annealing.
"""
@provides path MultiStepsInterpolatingPath(knots) = MultiStepsInterpolatingPath(knots, LinearInterpolator())

function interpolate(path::MultiStepsInterpolatingPath, beta) 

    # The task here is to reduce the interpolation problem to a "segment" between 
    # two adjacent knots. For example if n_knots = 3, and beta = 1/3, then in the following 
    # we would grab the fist and second knots, and rescale beta to 2/3.

    n_knots = length(path.knots)

    # First, find the two end points of the segment
    ref_index = ref_knot_index(beta, n_knots)
    target_index = ref_index + 1 

    # Second, rescale beta to be interpolating between the segment's endpoints
    delta = 1.0 / (n_knots - 1) # difference in original beta param between knots
    baseline_beta = (ref_index - 1) * delta 
    @assert baseline_beta ≤ beta "$baseline_beta $beta "
    rescaled_beta = (beta - baseline_beta) / delta 

    # The problem is now reduced to a segment, i.e. a path with only 2 knots: 
    segment = InterpolatingPath(path.knots[ref_index], path.knots[target_index], path.interpolator)
    
    # We can now invoke the machinery constructed for the special case with 2 knots:
    return InterpolatedLogPotential(segment, rescaled_beta)
end

ref_knot_index(beta, n_knots) = max(1, ceil(Int, beta * (n_knots - 1))) 

"""
$SIGNATURES

[`MultiStepsInterpolatingPath`](@ref) is already a [`path`](@ref), so return it.
"""
create_path(target::MultiStepsInterpolatingPath, inputs::Inputs) = target_is_already_a_path(target, inputs)

initialization(target::MultiStepsInterpolatingPath, rng::AbstractRNG, replica_index::Int64) = 
    initialization(target.knots[end], rng, replica_index)