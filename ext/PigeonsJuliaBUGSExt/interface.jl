#######################################
# Path interface
#######################################

# Initialization and iid sampling
function evaluate_and_initialize(model::JuliaBUGS.BUGSModel, rng::AbstractRNG)
    # Use JuliaBUGS 0.10 API: evaluate_with_rng!! returns (evaluation_env, log_densities)
    new_env, _ = JuliaBUGS.Model.evaluate_with_rng!!(rng, model)  # sample a new evaluation environment
    return JuliaBUGS.Model.initialize!(model, new_env)             # set the private_model's environment to the newly created one
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
# Default initialization returns Vector state (legacy)
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

# log_potential evaluation for Vector state (legacy, but kept for compatibility)
(log_potential::JuliaBUGSLogPotential)(flattened_values::AbstractVector) =
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

# log_potential evaluation for BUGSModel state (preserves types for discrete variables)
(log_potential::JuliaBUGSLogPotential)(model::JuliaBUGS.BUGSModel) =
    try
        # Use evaluate_with_env!! which operates on the model's evaluation_env directly
        _, log_densities = JuliaBUGS.Model.evaluate_with_env!!(
            model;
            temperature=log_potential.beta,
            transformed=model.transformed,
        )
        log_prior = log_densities.logprior
        tempered_log_joint = log_densities.tempered_logjoint
        return iszero(log_potential.beta) ? log_prior : tempered_log_joint
    catch e
        (isa(e, DomainError) || isa(e, BoundsError)) && return -Inf
        rethrow(e)
    end

# iid sampling - return the model itself as state to preserve type information
function Pigeons.sample_iid!(log_potential::JuliaBUGSLogPotential, replica, ::Pigeons.Shared)
    # Sample new values and initialize the model
    evaluate_and_initialize(log_potential.private_model, replica.rng)
    # Use the model itself as the state (preserves integer types for discrete variables)
    replica.state = log_potential.private_model
end

# parameter names for Vector state
Pigeons.sample_names(::Vector, log_potential::JuliaBUGSLogPotential) =
    [(Symbol(string(vn)) for vn in JuliaBUGS.Model.parameters(log_potential.private_model))...,:log_density]

# parameter names for BUGSModel state
Pigeons.sample_names(::JuliaBUGS.BUGSModel, log_potential::JuliaBUGSLogPotential) =
    [(Symbol(string(vn)) for vn in JuliaBUGS.Model.parameters(log_potential.private_model))...,:log_density]

# extract samples for Vector state
Pigeons.extract_sample(state::AbstractVector, log_potential::JuliaBUGSLogPotential) = 
    vcat(state, log_potential(state))

# extract samples for BUGSModel state
Pigeons.extract_sample(model::JuliaBUGS.BUGSModel, log_potential::JuliaBUGSLogPotential) = 
    vcat(JuliaBUGS.Model.getparams(model), log_potential(model))

# Specialized slice sampler for BUGSModel state
# This preserves integer types for discrete variables, allowing proper slice sampling
function Pigeons.slice_sample!(h::Pigeons.SliceSampler, model::JuliaBUGS.BUGSModel, 
                               log_potential, cached_lp, replica)
    # Iterate over each parameter and slice sample it in-place
    for vn in JuliaBUGS.Model.parameters(model)
        # Get the current value (could be scalar or array, integer or float)
        value = AbstractPPL.get(model.evaluation_env, vn)
        
        if value isa AbstractArray
            # For arrays, slice sample each element in-place
            for i in eachindex(value)
                # Create a pointer to this specific element
                pointer = Base.RefArray(value, i)
                # Slice sample this coordinate (will use integer path if eltype is Integer)
                Pigeons.slice_sample_coord!(h, replica, pointer, log_potential, cached_lp, 
                                           eltype(value))
            end
            # After modifying the array in-place, update the environment
            # (this ensures proper handling of immutable NamedTuples)
            model.evaluation_env = JuliaBUGS.BangBang.setindex!!(model.evaluation_env, value, vn)
        else
            # For scalars, wrap in a Ref
            pointer = Ref(value)
            # Slice sample this coordinate
            Pigeons.slice_sample_coord!(h, replica, pointer, log_potential, cached_lp, 
                                       typeof(value))
            # Update the model's evaluation environment with the new scalar value
            model.evaluation_env = JuliaBUGS.BangBang.setindex!!(model.evaluation_env, pointer[], vn)
        end
    end
    return cached_lp
end


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
