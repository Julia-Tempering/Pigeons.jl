Pigeons.default_reference(target::JuliaBUGSLogPotential) = 
    JuliaBUGSLogPotential(make_prior_model(target.model))
function make_prior_model(target_model::JuliaBUGS.BUGSModel)
    # copy underlying graph and remove all vertices that
    #   - are stochastic and observed: likelihood statements
    #   - aren't stochastic nor observed and whose only children are observations
    prior_graph = deepcopy(target_model.g)
    for (label, (code, node_meta)) in prior_graph.vertex_properties
        if node_meta.is_stochastic && node_meta.is_observed
            for parent_code in inneighbors(prior_graph, code)
                # TODO: this should keep recursing up the parent, removing all unnecessary
                # deterministic functions, not just one level
                parent_meta = prior_graph.vertex_properties[label_for(prior_graph, parent_code)][2]
                if !parent_meta.is_stochastic && !parent_meta.is_observed
                    rem_vertex!(prior_graph, parent_code)
                end
            end
            rem_vertex!(prior_graph, code)
        end
    end
    
    # make the corresponding evaluation environment
    prior_parameters = Set(getsym(k) for k in keys(prior_graph.vertex_properties))
    eval_env = target_model.evaluation_env
    prior_eval_env = NamedTuple(k => v for (k,v) in zip(keys(eval_env),eval_env) if k in prior_parameters)
    
    # create prior model and check consistency
    prior_model = JuliaBUGS.BUGSModel(prior_graph, prior_eval_env)
    @assert Set(prior_model.parameters) == Set(target_model.parameters)
    
    return prior_model
end