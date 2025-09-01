#=
We directly use JuliaBUGS.Model.getparams from JuliaBUGS 0.10
which properly handles parameter extraction with the correct ordering.
=#
getparams(model::JuliaBUGS.BUGSModel) = JuliaBUGS.Model.getparams(model)

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
