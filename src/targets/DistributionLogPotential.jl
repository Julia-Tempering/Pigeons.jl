"""
Provides a reference type for Pigeons based on an encapsulated Distribution type.
$FIELDS
"""
@auto struct DistributionLogPotential{D<:Distribution}
    """The encapsulated distribution."""
    dist::D
end

# evaluate the log density: general case
(ref::DistributionLogPotential)(x) = logpdf(ref.dist, x)

# univariate case
(ref::DistributionLogPotential{<:UnivariateDistribution})(x) = logpdf(ref.dist, first(x))

# iid sampling for array-type states
# general case
sample_iid!(ref::DistributionLogPotential, replica::Replica{<:AbstractArray}, shared) =
    rand!(replica.rng, ref.dist, replica.state)

# univariate case
function sample_iid!(
    ref::DistributionLogPotential{D}, 
    replica::Replica{<:AbstractArray},
    shared
    ) where {D<:UnivariateDistribution}
    replica.state[begin] = rand(replica.rng, ref.dist)
end

# Make it conform the LogDensityProblems interface
LogDensityProblems.logdensity(log_potential::DistributionLogPotential, x) = log_potential(x)
LogDensityProblems.dimension(log_potential::DistributionLogPotential) = length(log_potential.dist)
LogDensityProblems.dimension(::DistributionLogPotential{<:UnivariateDistribution}) = 1
