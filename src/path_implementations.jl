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
$TYPEDSIGNATURES
"""
@provides path create_path(ref, target, interpolator = LinearInterpolator()) = Path(ref, target, interpolator)

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


# 

"""
$FIELDS
Toy path for testing.
"""
struct TranslatedNormalPath{T}
    """Path between a MVN with mean zero at one end point and given `mean` at the other."""
    mean::T
end
interpolate(path::TranslatedNormalPath, beta) = Normal(beta * path.mean, 1)

function translated_normal_example(n_chains)
    path = TranslatedNormalPath(2.0)
    return discretize(path, equally_spaced(n_chains))
end
