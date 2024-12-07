#######################################
# Path interface
#######################################

# State initialization: state is a flattened vector of the parameters
# Note: JuliaBUGS.getparams creates a new vector on each call, so it is safe
# to call these for different Replicas
Pigeons.initialization(target::JuliaBUGSPath, _::AbstractRNG, _::Int64) =
    JuliaBUGS.getparams(target.model)

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
    last(last(JuliaBUGS._tempered_evaluate!!(
        log_potential.private_model, 
        flattened_values;
        temperature=log_potential.beta
    )))

# iid sampling
# Note: JuliaBUGS.getparams always allocates a new vector so there is no point
# of copying the result into the Replica's state; just replace it.
function Pigeons.sample_iid!(log_potential::JuliaBUGSLogPotential, replica, shared)
    new_env = first(JuliaBUGS.evaluate!!(replica.rng, log_potential.private_model)) # sample a new evaluation environment
    JuliaBUGS.initialize!(log_potential.private_model, new_env)                     # set the private_model's environment to the newly created one
    replica.state = JuliaBUGS.getparams(log_potential.private_model)                # finally, flatten the eval environment in the model and set that as the replica state
end
