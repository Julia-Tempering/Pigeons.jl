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

struct ScaledPrecisionNormalLogPotential
    precision::Float64
    dim::Int 
end

(log_potential::ScaledPrecisionNormalLogPotential)(x) = 
    -0.5 * log_potential.precision * sqr_norm(x) 

(log_potential::ScaledPrecisionNormalLogPotential)(x::StanState) = log_potential(x.unconstrained_parameters)

# Make it conform the LogDensityProblems interface
LogDensityProblems.logdensity(log_potential::ScaledPrecisionNormalLogPotential, x) = log_potential(x)
LogDensityProblems.dimension(log_potential::ScaledPrecisionNormalLogPotential) = log_potential.dim

LogDensityProblemsAD.ADgradient(::Symbol, log_potential::ScaledPrecisionNormalLogPotential, buffers::Augmentation) = 
    BufferedAD(log_potential, buffers)

function LogDensityProblems.logdensity_and_gradient(log_potential::BufferedAD{ScaledPrecisionNormalLogPotential}, x)
    logdens = log_potential.enclosed(x)
    log_potential.buffer .= -log_potential.enclosed.precision .* x
    return logdens, log_potential.buffer
end


"""
$SIGNATURES

Toy Multivariate Normal (MVN) path of distributions for testing: 
see section I.4.1 in Syed et al 2021. 
"""
@provides path ScaledPrecisionNormalPath(dim::Int) = 
    ScaledPrecisionNormalPath(1.0, 10.0, dim) 
precision(path::ScaledPrecisionNormalPath, beta) = 
    (1.0 - beta) * path.precision0 + beta * path.precision1
interpolate(path::ScaledPrecisionNormalPath, beta) = 
    ScaledPrecisionNormalLogPotential(precision(path, beta), path.dim)

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

analytic_lognormalization(path::ScaledPrecisionNormalPath) = 
    # log(Z_target) - log(Z_ref)
    # Z_i propto sigma_i = 1/sqrt(precision_i)
    # log(Z_i) = -0.5 log(precision_i)
    # => 0.5 * (log(prec_ref) - log(prec_target))
    0.5 * path.dim * (log(path.precision0) - log(path.precision1))

""" 
$SIGNATURES 

In this case, the target is already a [`path`](@ref), so return it. 
"""
create_path(target::ScaledPrecisionNormalPath, inputs::Inputs) = target

