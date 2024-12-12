#######################################
# Path interface
#######################################

get_symbol(::JuliaBUGS.VarName{sym}) where sym = sym

function Pigeons.JuliaBUGSPath(model::JuliaBUGS.BUGSModel)
    Pigeons.JuliaBUGSPath(
        model,
        Set(get_symbol(vn) for vn in model.parameters)
    )
end

# used for both initializing and iid sampling
# sample a new evaluation environment (without resampling observed data)
# Note: JuliaBUGS.evaluate!! deepcopies model.evaluation_env, so the
# new environment is completely independent of model.evaluation_env
_sample_iid(model::JuliaBUGS.BUGSModel, rng::AbstractRNG) = 
    first(JuliaBUGS.evaluate!!(rng, model; sample_all=false))

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
mutable struct JuliaBUGSLogPotential{TMod<:JuliaBUGS.BUGSModel, TF<:AbstractFloat, TPars<:Set}
    """
    A deep-enough copy of the original model that allows evaluation while
    avoiding race conditions between different Replicas.
    """
    private_model::TMod
    
    """
    Tempering parameter.
    """
    beta::TF

    """
    See [`JuliaBUGSPath`](@ref).
    """
    parameter_names::TPars
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
    JuliaBUGSLogPotential(private_model, beta, path.parameter_names)
end

# log_potential evaluation
(log_potential::JuliaBUGSLogPotential)(new_env) =
    try
        # update model evaluation_env with the one passed
        log_potential.private_model = JuliaBUGS.initialize!(log_potential.private_model, new_env)
        
        # FIXME (temporary hack): ideally we would just call
        #     `_tempered_evaluate!!(log_potential.private_model; temperature=log_potential.beta)
        # but the method does not exist yet, and so we must flatten first
        # see https://github.com/TuringLang/JuliaBUGS.jl/issues/260
        flattened_values = JuliaBUGS.getparams(log_potential.private_model)
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

# custom sample extraction, needed because
#   1) evaluation_env contains both observations and parameters (only want the latter)
#   2) there is no copy method for NamedTuples
Pigeons.extract_sample(state::NamedTuple, log_potential::JuliaBUGSLogPotential) =
    NamedTuple(k => copy(v) for (k,v) in zip(keys(state), state) if k in log_potential.parameter_names)

