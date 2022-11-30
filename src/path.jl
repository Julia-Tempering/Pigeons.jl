"""
A continuum of log_potential's interpolating between two end-points.

Convention: the continuum is indexed on [0, 1] 
"""

interpolate(path, beta) = InterpolatedLogPotential(path, beta)
discretize(path, betas) = [interpolate(path, beta) for beta in betas]

# use this to create new types of interpolations
interpolate(interpolator, ref, target, beta, x) = @abstract
struct LinearInterpolator end
interpolate(::LinearInterpolator, ref_log_potential, target_log_potential, beta, x) = 
    @weighted(1.0 - beta, ref_log_potential(x)) +
    @weighted(beta,       target_log_potential(x))

path(ref, target, interpolator = LinearInterpolator()) = Path(ref, target, interpolator)

# internal representation of paths 
struct Path{LP1,LP2,I} # LP = log_potential type, i.e. lp isa LP => supports lp(point)
    ref::LP1
    target::LP2
    interpolator::I
end
struct InterpolatedLogPotential{LP1,LP2,I}
    path::Path{LP1,LP2,I}
    beta::Float64
end
(interpolated::InterpolatedLogPotential)(x) = 
    interpolate(interpolated.path.interpolator, interpolated.path.ref, interpolated.path.target, interpolated.beta, x)
