# default representation of paths based on interpolating two log_potential's

# use this extension point to create new types of interpolations
interpolate(interpolator, ref, target, beta, x) = @abstract
struct LinearInterpolator end
function interpolate(::LinearInterpolator, ref_log_potential, target_log_potential, beta, x) 
    @assert 0.0 ≤ beta ≤ 1.0
    @weighted(1.0 - beta, ref_log_potential(x)) +
    @weighted(beta,       target_log_potential(x))
end

"""
$SIGNATURES

Given a reference [`log_potential`](@ref) and a target [`log_potential`](@ref), 
return a [`path`](@ref) interpolating between them. 

By default, the `interpolator` is a `LinearInterpolator`, i.e. 
standard annealing.
"""
@provides path create_path(ref, target, interpolator = LinearInterpolator()) = InterpolatingPath(ref, target, interpolator)

struct InterpolatingPath{LP1,LP2,I} # LP = log_potential type, i.e. lp isa LP => supports lp(point)
    ref::LP1
    target::LP2
    interpolator::I
end
struct InterpolatedLogPotential{LP1,LP2,I}
    path::InterpolatingPath{LP1,LP2,I}
    beta::Float64
end
(interpolated::InterpolatedLogPotential)(x) = 
    interpolate(interpolated.path.interpolator, interpolated.path.ref, interpolated.path.target, interpolated.beta, x)

interpolate(path::InterpolatingPath, beta) = InterpolatedLogPotential(path, beta)


