#######################################
# Path interface
#######################################

# Initialization and iid sampling
function evaluate_and_initialize(model::JuliaBUGS.BUGSModel, rng::AbstractRNG)
    new_env = first(JuliaBUGS.evaluate!!(rng, model)) # sample a new evaluation environment
    return JuliaBUGS.initialize!(model, new_env)      # set the private_model's environment to the newly created one
end

# used for both initializing and iid sampling
# Note: state is a flattened vector of the parameters
# Also, the vector is **concretely typed**. This means that if the evaluation
# environment contains floats and integers, the latter will be cast to float.
_sample_iid(model::JuliaBUGS.BUGSModel, rng::AbstractRNG) = 
    getparams(evaluate_and_initialize(model, rng)) # flatten the unobserved parameters in the model's eval environment and return

# Note: JuliaBUGS.getparams creates a new vector on each call, so it is safe
# to call _sample_iid during initialization (**sequentially**, as done as of time
# of writing) for different Replicas (i.e., they won't share the same state).
Pigeons.initialization(target::JuliaBUGSPath, rng::AbstractRNG, _::Int64) =
    _sample_iid(target.model, rng)

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

# log_potential evaluation
(log_potential::JuliaBUGSLogPotential)(flattened_values) =
    try
        # Evaluate at given values using JuliaBUGS 0.10 API
        # We need both logprior and tempered_logjoint (for beta==0 and beta>0 cases)
        _, log_densities = JuliaBUGS.evaluate_with_values!!(
            log_potential.private_model,
            flattened_values;
            temperature=log_potential.beta,
            transformed=log_potential.private_model.transformed,
        )
        log_prior = log_densities.logprior
        tempered_log_joint = log_densities.tempered_logjoint
        # avoid potential 0*Inf (= NaN)
        return iszero(log_potential.beta) ? log_prior : tempered_log_joint
    catch e
        (isa(e, DomainError) || isa(e, BoundsError)) && return -Inf
        rethrow(e)
    end

# iid sampling
function Pigeons.sample_iid!(log_potential::JuliaBUGSLogPotential, replica, shared)
    replica.state = _sample_iid(log_potential.private_model, replica.rng)
end

# parameter names
Pigeons.sample_names(::Vector, log_potential::JuliaBUGSLogPotential) =
    [(Symbol(string(vn)) for vn in JuliaBUGS.parameters(log_potential.private_model))...,:log_density]

# Parallelism invariance
Pigeons.recursive_equal(a::Union{JuliaBUGSPath,JuliaBUGSLogPotential}, b) =
    Pigeons._recursive_equal(a,b)
function Pigeons.recursive_equal(a::T, b) where T <: JuliaBUGS.BUGSModel
    included = (:transformed, :model_def, :data)
    excluded = Tuple(setdiff(fieldnames(T), included))
    Pigeons._recursive_equal(a,b,excluded)
end
# just check the betas match, the model is already checked within path
Pigeons.recursive_equal(a::AbstractVector{<:JuliaBUGSLogPotential}, b) =    
    all(lp1.beta == lp2.beta for (lp1,lp2) in zip(a,b))
