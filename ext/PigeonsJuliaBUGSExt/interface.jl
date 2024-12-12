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
    private_model = JuliaBUGS.BUGSModel(
        model, 
        deepcopy(model.g),
        model.parameters, model.flattened_graph_node_data.sorted_nodes,
        deepcopy(model.evaluation_env)
    )
    JuliaBUGSLogPotential(private_model, beta)
end

# log_potential evaluation
(log_potential::JuliaBUGSLogPotential)(flattened_values) =
    try 
        last(last(JuliaBUGS._tempered_evaluate!!(
            log_potential.private_model, 
            flattened_values;
            temperature=log_potential.beta
        )))
    catch e
        (isa(e, DomainError) || isa(e, BoundsError)) && return -Inf
        rethrow(e)
    end

# iid sampling
function Pigeons.sample_iid!(log_potential::JuliaBUGSLogPotential, replica, shared)
    replica.state = _sample_iid(log_potential.private_model, replica.rng)
end
