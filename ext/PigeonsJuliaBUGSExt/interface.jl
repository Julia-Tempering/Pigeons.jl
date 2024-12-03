#=
JuliaBUGS state is an "evaluation environment" (NamedTuple), containing only
the parameters of the model (i.e., with observations and other variables deleted).
This is so that the state corresponds to the evaluation_env of the prior
=#
function Pigeons.initialization(target::JuliaBUGSLogPotential, _::AbstractRNG, _::Int64)
    ev_env = target.model.evaluation_env
    model_params_syms = Set(AbstractPPL.getsym(vn) for vn in target.model.parameters)
    NamedTuple(k => v for (k,v) in zip(keys(ev_env), ev_env) if k in model_params_syms)
end

# iid sampling from the prior is straightforward because state coincides with evaluation_env
function Pigeons.sample_iid!(ref_lp::JuliaBUGSLogPotential, replica, shared)
    replica.state = first(JuliaBUGS.evaluate!!(replica.rng, ref_lp.model))
end

# log_potential evaluation
# note: `initialize!` merges, so it works even when eval_env has more fields than
# log_potential.model.evaluation_env (which happens when log_potential is the target)
function (log_potential::JuliaBUGSLogPotential)(eval_env)
    model = JuliaBUGS.initialize!(log_potential.model, eval_env)
    return last(JuliaBUGS.evaluate!!(model))
end

# Set the default reference to a JuliaBUGS model for the prior 
Pigeons.default_reference(target::JuliaBUGSLogPotential) = 
    JuliaBUGSLogPotential(make_prior_model(target.model))

# Obtain the JuliaBUGS model for the prior by pruning the underlying DAG
function make_prior_model(target_model::JuliaBUGS.BUGSModel)
    # copy the target model graph, then drop any nodes that are not parameters
    prior_graph = deepcopy(target_model.g)
    model_params_syms = Set(AbstractPPL.getsym(vn) for vn in target_model.parameters)
    for (vn, (code, _)) in prior_graph.vertex_properties
        if AbstractPPL.getsym(vn) ∉ model_params_syms
            rem_vertex!(prior_graph, code)
        end
    end
    
    # make the corresponding evaluation environment
    eval_env = target_model.evaluation_env
    prior_eval_env = NamedTuple(
        k => copy(v) for (k,v) in zip(keys(eval_env),eval_env) if k in model_params_syms)
    
    # create prior model and check consistency
    prior_model = JuliaBUGS.BUGSModel(
        prior_graph, prior_eval_env; is_transformed = target_model.transformed)
    @assert Set(prior_model.parameters) == Set(target_model.parameters)
    
    return prior_model
end

