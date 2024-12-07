###############################################################################
# InterpolatingPath approach, where we built a separate prior model from the
# target one.
# Not used right now, but keeping it here in case we want to revert back to
# this approach
###############################################################################

get_unique_params(model::JuliaBUGS.BUGSModel) = Set(AbstractPPL.getsym(vn) for vn in model.parameters)

# Set the default reference to a JuliaBUGS model for the prior 
Pigeons.default_reference(target::JuliaBUGSLogPotential) = 
    JuliaBUGSLogPotential(make_prior_model(target.model))

# Obtain the JuliaBUGS model for the prior by pruning the underlying DAG
function make_prior_model(target_model::JuliaBUGS.BUGSModel)
    # copy the target model graph, then drop any nodes that are not parameters
    prior_graph = deepcopy(target_model.g)
    model_params_syms = unique_params(target_model.parameters)
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

