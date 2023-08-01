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

# iid sampling
# general case
function sample_iid!(ref::DistributionLogPotential, replica, shared)
    rand!(replica.rng, ref.dist, replica.state)
end

# univariate case
function sample_iid!(ref::DistributionLogPotential{D}, replica, shared) where {D<:UnivariateDistribution}
    replica.state[begin] = rand(replica.rng, ref.dist)
end
