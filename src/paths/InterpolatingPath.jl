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
