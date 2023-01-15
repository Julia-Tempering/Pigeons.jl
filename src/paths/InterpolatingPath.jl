# Paths based on interpolating two log_potential's

@concrete struct InterpolatingPath
    ref
    target
    interpolator
end

"""
$SIGNATURES

Given a reference [`log_potential`](@ref) and a target [`log_potential`](@ref), 
return a [`path`](@ref) interpolating between them. 

By default, the `interpolator` is a `LinearInterpolator`, i.e. 
standard annealing.
"""
@provides path InterpolatingPath(ref, target) = InterpolatingPath(ref, target, LinearInterpolator())

interpolate(path::InterpolatingPath, beta) = InterpolatedLogPotential(path, beta)

# use this extension point to create new types of interpolations, e.g. q-path, etc.
interpolate(interpolator, ref, target, beta, x) = @abstract
struct LinearInterpolator end
function interpolate(::LinearInterpolator, ref_log_potential, target_log_potential, beta, x) 
    @assert 0.0 ≤ beta ≤ 1.0
    @weighted(1.0 - beta, ref_log_potential(x)) +
    @weighted(beta,       target_log_potential(x))
end

