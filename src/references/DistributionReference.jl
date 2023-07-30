"""
Provides a reference type for Pigeons based on an encapsulated Distribution type.
$FIELDS
"""
@auto struct DistributionReference{D<:Distribution}
    """The encapsulated distribution."""
    dist::D
end

# evaluate the log density: general case
(ref::DistributionReference)(x) = logpdf(ref.dist, x)

# univariate case
(ref::DistributionReference{<:UnivariateDistribution})(x) = logpdf(ref.dist, x[begin])

# iid sampling
# general case
function sample_iid!(ref::DistributionReference, replica, shared)
    rand!(replica.rng, ref.dist, replica.state)
end

# univariate case
function sample_iid!(ref::DistributionReference{D}, replica, shared) where {D<:UnivariateDistribution}
    replica.state[begin] = rand(replica.rng, ref.dist)
end
