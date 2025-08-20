#=
Tweak of JuliaBUGS.getparams to allow for flattened vectors of mixed type
Adapts to JuliaBUGS 0.10 API changes (parameters as accessor, GraphEvaluationData fields).
Also hardens mixed-type eltype inference to handle scalars and arrays.
=#
function type_join_eval_env(env)
    T = Union{}
    for v in env
        tv = v isa AbstractArray ? eltype(v) : typeof(v)
        T = promote_type(T, tv)
    end
    return T
end
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
    # Use the parameter order consistent with logdensity evaluation
    for v in model.graph_evaluation_data.sorted_parameters
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
    # Deep copy graph and evaluation environment; rebuild GraphEvaluationData
    g = deepcopy(model.g)
    sorted_nodes = model.graph_evaluation_data.sorted_nodes
    new_graph_eval_data = JuliaBUGS.Model.GraphEvaluationData(g, sorted_nodes)
    new_env = deepcopy(model.evaluation_env)
    new_mutable_symbols = JuliaBUGS.Model.get_mutable_symbols(new_graph_eval_data)

    # Use keyword copy-constructor to avoid positional field mismatches
    return JuliaBUGS.BUGSModel(
        model;
        g = g,
        evaluation_env = new_env,
        graph_evaluation_data = new_graph_eval_data,
        mutable_symbols = new_mutable_symbols,
    )
end
