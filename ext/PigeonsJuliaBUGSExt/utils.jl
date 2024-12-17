#=
Tweak of JuliaBUGS.getparams to allow for flattened vectors of mixed type
=#
type_join_eval_env(env) = typejoin(Set(eltype(v) for v in env)...)
function getparams(model::JuliaBUGS.BUGSModel)
    param_length = if model.transformed
        model.transformed_param_length
    else
        model.untransformed_param_length
    end

    # search for an umbrella type for all parameters in the model to avoid
    # promotion of e.g. ints to floats. For models with a unique parameter
    # type T, it holds that TMix=T. 
    TMix = type_join_eval_env(model.evaluation_env)
    param_vals = Vector{TMix}(undef, param_length)
    pos = 1
    for v in model.parameters
        if !model.transformed
            val = AbstractPPL.get(model.evaluation_env, v)
            len = model.untransformed_var_lengths[v]
            if val isa AbstractArray
                param_vals[pos:(pos + len - 1)] .= vec(val)
            else
                param_vals[pos] = val
            end
        else
            (; node_function, loop_vars) = model.g[v]
            dist = node_function(model.evaluation_env, loop_vars)
            transformed_value = Bijectors.transform(
                Bijectors.bijector(dist), AbstractPPL.get(model.evaluation_env, v)
            )
            len = model.transformed_var_lengths[v]
            if transformed_value isa AbstractArray
                param_vals[pos:(pos + len - 1)] .= vec(transformed_value)
            else
                param_vals[pos] = transformed_value
            end
        end
        pos += len
    end
    return param_vals
end

function make_private_model_copy(model::JuliaBUGS.BUGSModel)
    g = deepcopy(model.g)
    parameters = model.parameters
    sorted_nodes = model.flattened_graph_node_data.sorted_nodes
    return JuliaBUGS.BUGSModel(
        model.transformed,
        sum(model.untransformed_var_lengths[v] for v in parameters),
        sum(model.transformed_var_lengths[v] for v in parameters),
        model.untransformed_var_lengths,
        model.transformed_var_lengths,
        deepcopy(model.evaluation_env),
        parameters,
        JuliaBUGS.FlattenedGraphNodeData(g, sorted_nodes),
        g,
        nothing,
        model.model_def,
        model.data
    )
end
