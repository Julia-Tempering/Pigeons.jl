#=
Custom getparams for JuliaBUGS.BUGSModel that preserves parameter element
types (e.g., keeps Int parameters as Int instead of promoting to Float64)
while following JuliaBUGS 0.10’s ordering and length semantics.

Returns a single-typed vector (e.g., Vector{Real} when mixing Int and Float),
matching Pigeons’ historical behavior.
=#

local_param_eltype(x) = x isa AbstractArray ? eltype(x) : typeof(x)

function _infer_param_element_type(
    model::JuliaBUGS.BUGSModel,
    evaluation_env=model.evaluation_env,
)
    tmix = Union{}
    for v in JuliaBUGS.Model.parameters(model)
        if !model.transformed
            val = AbstractPPL.get(evaluation_env, v)
            T = local_param_eltype(val)
        else
            (; node_function, loop_vars) = model.g[v]
            dist = node_function(evaluation_env, loop_vars)
            transformed_value = Bijectors.transform(
                Bijectors.bijector(dist), AbstractPPL.get(evaluation_env, v)
            )
            T = local_param_eltype(transformed_value)
        end
        tmix = tmix === Union{} ? T : typejoin(tmix, T)
    end
    return tmix === Union{} ? Float64 : tmix
end

function getparams(model::JuliaBUGS.BUGSModel, evaluation_env=model.evaluation_env)
    param_length = if model.transformed
        model.transformed_param_length
    else
        model.untransformed_param_length
    end

    TMix = _infer_param_element_type(model, evaluation_env)
    param_vals = Vector{TMix}(undef, param_length)
    pos = 1
    for v in JuliaBUGS.Model.parameters(model)
        if !model.transformed
            val = AbstractPPL.get(evaluation_env, v)
            len = model.untransformed_var_lengths[v]
            if val isa AbstractArray
                copyto!(param_vals, pos, vec(val), 1, len)
            else
                param_vals[pos] = val
            end
        else
            (; node_function, loop_vars) = model.g[v]
            dist = node_function(evaluation_env, loop_vars)
            transformed_value = Bijectors.transform(
                Bijectors.bijector(dist), AbstractPPL.get(evaluation_env, v)
            )
            len = model.transformed_var_lengths[v]
            if transformed_value isa AbstractArray
                copyto!(param_vals, pos, vec(transformed_value), 1, len)
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
    new_mutable_symbols = JuliaBUGS.Model.get_mutable_symbols(new_graph_eval_data)
    new_env = JuliaBUGS.Model.smart_copy_evaluation_env(model.evaluation_env, new_mutable_symbols)

    # Use keyword copy-constructor to avoid positional field mismatches
    # Note: We force evaluation_mode to UseGraph() and set log_density_computation_function to nothing
    # to avoid serialization issues with generated functions that don't exist in other processes
    return JuliaBUGS.BUGSModel(
        model;
        g = g,
        evaluation_env = new_env,
        graph_evaluation_data = new_graph_eval_data,
        mutable_symbols = new_mutable_symbols,
        evaluation_mode = JuliaBUGS.Model.UseGraph(),  # Force graph-based evaluation
        log_density_computation_function = nothing,     # Clear generated function reference
    )
end

import Serialization: serialize, deserialize

function Serialization.serialize(s::Serialization.AbstractSerializer, path::JuliaBUGSPath{T}) where {T}
    Serialization.writetag(s.io, Serialization.OBJECT_TAG)
    Serialization.serialize(s, JuliaBUGSPath)
    model = path.model
    Serialization.serialize(s, model.model_def)
    Serialization.serialize(s, model.data)
    Serialization.serialize(s, model.evaluation_env)
    Serialization.serialize(s, model.transformed)
    return nothing
end

function Serialization.deserialize(s::Serialization.AbstractSerializer, ::Type{JuliaBUGSPath})
    model_def = Serialization.deserialize(s)
    data = Serialization.deserialize(s)
    evaluation_env = Serialization.deserialize(s)
    transformed = Serialization.deserialize(s)
    model = JuliaBUGS.compile(model_def, data, evaluation_env; skip_validation=true)
    model = JuliaBUGS.settrans(model, transformed)
    return JuliaBUGSPath(model)
end
