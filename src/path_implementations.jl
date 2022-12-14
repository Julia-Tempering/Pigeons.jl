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
By default, the `interpolator` is a `LinearInterpolator`, i.e. 
standard annealing.
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


# Toy examples for testing

"""
$FIELDS
Toy path for testing.
"""
struct TranslatedNormalPath
    """Path between a MVN with mean zero at one end point and given `mean` at the other."""
    mean::Float64
end
interpolate(path::TranslatedNormalPath, beta) = Normal(beta * path.mean, 1)

"""
$FIELDS
Toy path for testing.
"""
struct ScaledPrecisionNormalPath
    precision0::Float64
    precision1::Float64
    dim::Int
end
ScaledPrecisionNormalPath(dim::Int) = ScaledPrecisionNormalPath(1.0, 10.0, dim) 
precision(path::ScaledPrecisionNormalPath, beta) = (1.0 - beta) * path.precision0 + beta * path.precision1
interpolate(path::ScaledPrecisionNormalPath, beta) = MultivariateNormal(zeros(path.dim), Matrix(I, path.dim, path.dim) / precision(path, beta))

"""
$TYPEDSIGNATURES
Toy path for testing: see section I.4.1 in Syed et al 2021. 
"""
function scaled_normal_example(n_chains, dim)
    path = ScaledPrecisionNormalPath(dim)
    return discretize(path, Schedule(n_chains))
end

function analytic_cumulativebarrier(path::ScaledPrecisionNormalPath)
    b = beta(path.dim / 2.0, path.dim / 2.0)
    function cumulativebarrier(beta)
        sigma0 = 1.0 / sqrt(path.precision0)
        sigmab = 1.0 / sqrt(precision(path, beta))
        return 2^(2.0-path.dim) / b * log(sigma0 / sigmab)
    end
    return cumulativebarrier
end