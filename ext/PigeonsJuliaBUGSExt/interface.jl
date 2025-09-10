#######################################
# Path interface
#######################################

# Initialization and iid sampling
function evaluate_and_initialize(model::JuliaBUGS.BUGSModel, rng::AbstractRNG)
    new_env, _ = JuliaBUGS.Model.evaluate_with_rng!!(rng, model)  # sample a new evaluation environment
    return JuliaBUGS.initialize!(model, new_env)      # set the private_model's environment to the newly created one
end

# Draw a single prior sample and return flattened parameters
sample_params_from_prior(model::JuliaBUGS.BUGSModel, rng::AbstractRNG) =
    getparams(evaluate_and_initialize(model, rng))


# Note: JuliaBUGS.getparams creates a new vector on each call, so it is safe
# to call _sample_iid during initialization (**sequentially**, as done as of time
# of writing) for different Replicas (i.e., they won't share the same state).
Pigeons.initialization(target::JuliaBUGSPath, rng::AbstractRNG, _::Int64) =
    sample_params_from_prior(target.model, rng)

# target is already a Path
Pigeons.create_path(target::JuliaBUGSPath, ::Inputs) = target

#######################################
# Log-potential interface
#######################################

"""
$SIGNATURES

A log-potential built from a [`JuliaBUGSPath`](@ref) for a specific inverse 
temperature parameter.

$FIELDS
"""
struct JuliaBUGSLogPotential{TMod<:JuliaBUGS.BUGSModel, TF<:AbstractFloat}
    """
    A deep-enough copy of the original model that allows evaluation while
    avoiding race conditions between different Replicas.
    """
    private_model::TMod
    
    """
    Tempering parameter.
    """
    beta::TF
end

# make a log-potential by creating a new model with independent graph and 
# evaluation environment. Both of these could be modified during density
# evaluations and/or during Gibbs sampling
function Pigeons.interpolate(path::JuliaBUGSPath, beta)
    model = path.model
    private_model = make_private_model_copy(model)
    JuliaBUGSLogPotential(private_model, beta)
end

# log_potential evaluation for Vector state (legacy, but kept for compatibility)
function (log_potential::JuliaBUGSLogPotential)(flattened_values::AbstractVector)
    try
        # Evaluate at given values using JuliaBUGS 0.10 API
        # evaluate_with_values!! returns (evaluation_env, log_densities_namedtuple)
        _, log_densities = JuliaBUGS.Model.evaluate_with_values!!(
            log_potential.private_model,
            flattened_values;
            temperature=log_potential.beta,
            transformed=log_potential.private_model.transformed,
        )
        # log_densities is a NamedTuple with fields: logprior, loglikelihood, tempered_logjoint
        log_prior = log_densities.logprior
        tempered_log_joint = log_densities.tempered_logjoint
        # avoid potential 0*Inf (= NaN)
        return iszero(log_potential.beta) ? log_prior : tempered_log_joint
    catch e
        (isa(e, DomainError) || isa(e, BoundsError)) && return -Inf
        rethrow(e)
    end
end

# iid sampling - extract parameters as Vector to match initialization type
function Pigeons.sample_iid!(log_potential::JuliaBUGSLogPotential, replica, ::Pigeons.Shared)
    # Draw exactly from the reference (prior) when beta=0
    # Reference chains are the only ones for which sample_iid! is invoked.
    replica.state = sample_params_from_prior(log_potential.private_model, replica.rng)
end

# parameter names for Vector state
Pigeons.sample_names(::Vector, log_potential::JuliaBUGSLogPotential) =
    [(Symbol(string(vn)) for vn in JuliaBUGS.parameters(log_potential.private_model))..., :log_density]

# extract samples for Vector state
Pigeons.extract_sample(state::Vector, log_potential::JuliaBUGSLogPotential) =
    vcat(state, log_potential(state))

# Parallelism invariance
Pigeons.recursive_equal(a::Union{JuliaBUGSPath,JuliaBUGSLogPotential}, b) =
    Pigeons._recursive_equal(a, b)
# just check the betas match, the model is already checked within path
Pigeons.recursive_equal(a::AbstractVector{<:JuliaBUGSLogPotential}, b) =
    all(lp1.beta == lp2.beta for (lp1, lp2) in zip(a, b))

# BUGSModel-specific equality: compare only stable fields to avoid nondeterminism
# in evaluation caches and generated functions while preserving true model identity.
function Pigeons.recursive_equal(a::T, b) where {T<:JuliaBUGS.BUGSModel}
    included = (:transformed, :model_def, :data)
    excluded = Tuple(setdiff(fieldnames(T), included))
    return Pigeons._recursive_equal(a, b, excluded)
end

#######################################
# Robustness for log-ratio evaluation
#######################################

# Numerically robust log-ratio for a vector of JuliaBUGS log-potentials.
#
# Rationale:
# - At support boundaries, the same state evaluated at two betas can give
#   lp_num == -Inf and lp_den == -Inf (or both Inf). The default lp_num - lp_den
#   becomes (-Inf) - (-Inf) or (Inf - Inf) which is NaN.
# - These NaNs would leak into swap statistics and PT adaptation, tripping the
#   “no NaN log potentials” test and destabilizing schedules.
# Policy:
# - If both sides are infinite with the same sign, return 0.0 (ratio 1.0) to
#   stay well-defined and avoid NaNs. Otherwise, compute the normal difference.
function Pigeons.log_unnormalized_ratio(
    lps::AbstractVector{<:JuliaBUGSLogPotential},
    numerator::Int,
    denominator::Int,
    state,
)
    lp_num = lps[numerator](state)
    lp_den = lps[denominator](state)
    if (lp_num == -Inf && lp_den == -Inf) || (lp_num == Inf && lp_den == Inf)
        # Indeterminate form; map to a neutral, finite value to avoid NaNs.
        return 0.0
    end
    ans = lp_num - lp_den
    if isnan(ans)
        # If a NaN still arises, surface a clear error with context.
        error("Got NaN log-unnormalized ratio; Dumping information:\n\tlp_num=$lp_num\n\tlp_den=$lp_den\n\tState=$state")
    end
    return ans
end

#######################################
# Robustness for swap acceptance
#######################################

# Robust swap acceptance for JuliaBUGS paths.
#
# Rationale:
# - Acceptance uses exp(stat1.log_ratio + stat2.log_ratio). With +Inf and -Inf
#   from two chains, the sum becomes NaN (0/0) and breaks stats/adaptation.
# Policy:
# - Finite sum: standard min(1, exp(sum)).
# - NaN from opposite infinities: treat as 1.0 (neutral accept for 0/0 case).
# - ±Inf sum: accept if +Inf, reject if -Inf.
_is_opposite_infinities(a, b) = isinf(a) && isinf(b) && signbit(a) != signbit(b)

function _robust_acceptance(stat1, stat2)
    s = stat1.log_ratio + stat2.log_ratio
    if isfinite(s)
        return min(1.0, exp(s))
    elseif isnan(s)
        # (+Inf) + (-Inf) → NaN; interpret as a neutral accept.
        return _is_opposite_infinities(stat1.log_ratio, stat2.log_ratio) ? 1.0 : 0.0
    else
        # s is ±Inf
        return s > 0 ? 1.0 : 0.0
    end
end

# Recorder hook using the robust acceptance above to avoid NaNs in recorded
# statistics, while still recording the original log-ratios for diagnostics.
function Pigeons.record_swap_stats!(
    pair_swapper::AbstractVector{<:JuliaBUGSLogPotential},
    recorders,
    chain1::Int,
    stat1,
    chain2::Int,
    stat2,
)
    acceptance_pr = _robust_acceptance(stat1, stat2)
    key1 = (chain1, chain2)
    key2 = (chain2, chain1)
    Pigeons.@record_if_requested!(recorders, :swap_acceptance_pr, (key1, acceptance_pr))
    Pigeons.@record_if_requested!(recorders, :log_sum_ratio, (key1, stat1.log_ratio))
    Pigeons.@record_if_requested!(recorders, :log_sum_ratio, (key2, stat2.log_ratio))
end

# Swap decision mirroring the robust acceptance calculation. Identical to the
# default when the sum is finite; well-defined in indeterminate cases.
function Pigeons.swap_decision(
    pair_swapper::AbstractVector{<:JuliaBUGSLogPotential},
    chain1::Int,
    stat1,
    chain2::Int,
    stat2,
)
    acceptance_pr = _robust_acceptance(stat1, stat2)
    uniform = chain1 < chain2 ? stat1.uniform : stat2.uniform
    return uniform < acceptance_pr
end
