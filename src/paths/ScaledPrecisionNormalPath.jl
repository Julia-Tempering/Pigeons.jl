"""
A [`path`](@ref) of zero-mean normals for testing; contains:
$FIELDS
"""
struct ScaledPrecisionNormalPath
    """Precision parameter of the reference."""
    precision0::Float64
    """Precision parameter of the target."""
    precision1::Float64
    """Dimensionality."""
    dim::Int
end
"""
$SIGNATURES

Toy path for testing: see section I.4.1 in Syed et al 2021. 
"""
ScaledPrecisionNormalPath(dim::Int) = ScaledPrecisionNormalPath(1.0, 10.0, dim) 
precision(path::ScaledPrecisionNormalPath, beta) = (1.0 - beta) * path.precision0 + beta * path.precision1
interpolate(path::ScaledPrecisionNormalPath, beta) = MultivariateNormal(zeros(path.dim), Matrix(I, path.dim, path.dim) / precision(path, beta))

"""
$SIGNATURES

Toy path for testing: see section I.4.1 in Syed et al 2021. 
"""
function scaled_normal_example(n_chains, dim)
    path = ScaledPrecisionNormalPath(dim)
    return discretize(path, Schedule(n_chains))
end

"""
$SIGNATURES

Known cumulative barrier used for testing, 
from [Predescu et al., 2003](https://aip.scitation.org/doi/10.1063/1.1644093).
"""
function analytic_cumulativebarrier(path::ScaledPrecisionNormalPath)
    b = beta(path.dim / 2.0, path.dim / 2.0)
    function cumulativebarrier(beta)
        sigma0 = 1.0 / sqrt(path.precision0)
        sigmab = 1.0 / sqrt(precision(path, beta))
        return 2^(2.0-path.dim) / b * log(sigma0 / sigmab)
    end
    return cumulativebarrier
end