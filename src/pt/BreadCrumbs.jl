"""
A struct that provides a basic, user-friendly interface to Pigeons. Only two inputs
are required, in positional order:
$FIELDS

!!! note

    The PT state is initialized using a random sample from the reference.  
"""
struct BreadCrumbs{TRefDist <: Distributions.Distribution, TTarget}
    """A function that evaluates the target log potential"""
    target_log_potential::TTarget
    """A Distributions.jl distribution used as reference"""
    reference_distribution::TRefDist
end

# Target for a BreadCrumbs input
struct BreadCrumbsTarget{TBC <: BreadCrumbs}
    bc::TBC
end
(bct::BreadCrumbsTarget)(x) = bct.bc.target_log_potential(x)
default_explorer(::BreadCrumbsTarget) = SliceSampler()

# initialization
# general case
function initialization(bct::BreadCrumbsTarget, rng::AbstractRNG, ::Int)
    rand(rng, bct.bc.reference_distribution)
end
# univariate case: need to wrap in vector to make the state mutable
function initialization(
    bct::TBCT,
    rng::AbstractRNG,
    ::Int
    ) where {TRD<:Distributions.UnivariateDistribution, TBC<:BreadCrumbs{TRD}, TBCT<:BreadCrumbsTarget{TBC}}
    [rand(rng, bct.bc.reference_distribution)]
end

# reference for a BreadCrumbs input
struct BreadCrumbsReference{TBC <: BreadCrumbs}
    bc::TBC
end
(bcr::BreadCrumbsReference)(x) = logpdf(bcr.bc.reference_distribution, x)
default_reference(bct::BreadCrumbsTarget) = BreadCrumbsReference(bct.bc)

# sampling from the reference
# general case
sample_iid!(bcr::BreadCrumbsReference, replica, shared) =
    rand!(replica.rng, bcr.bc.reference_distribution, replica.state)
# univariate case
function sample_iid!(
    bcr::TBCR,
    replica,
    shared
    ) where {TRD<:Distributions.UnivariateDistribution, TBC<:BreadCrumbs{TRD}, TBCR<:BreadCrumbsReference{TBC}}
    replica.state[] = rand(rng, bcr.bc.reference_distribution)
end
