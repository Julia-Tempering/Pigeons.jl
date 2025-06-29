"""
A Gaussian tree variational reference
"""


@kwdef mutable struct TreeReference
    edges::Vector{Tuple{Symbol, Symbol, Any}} = Vector{Tuple{Symbol, Symbol, Any}}()
    means::Dict{Symbol, Any} = Dict{Symbol, Any}()
    standard_deviations::Dict{Symbol, Any} = Dict{Symbol, Any}()
    first_tuning_round::Int = 6 
    num_nodes::Int = 0

    function TreeReference(edges, means, standard_deviations, first_tuning_round, num_nodes)
        @assert length(edges)==num_nodes-1 || length(edges)==(num_nodes*(num_nodes-1))/2
        @assert first_tuning_round ≥ 1
        new(edges, means, standard_deviations, first_tuning_round, num_nodes)
    end
end


dim(variational::TreeReference) = variational.num_nodes
function activate_variational(variational::TreeReference, iterators::Iterators)
    iterators.round ≥ variational.first_tuning_round ? true : false
end

variational_recorder_builders(::TreeReference) = [_transformed_online]


#TODO
function update_reference!(reduced_recorders, variational::TreeReference, state)
end
#TODO
function tree_decomposition()
end
#TODO
function compute_mutual_info()
end

#TODO
function prims_spanning_tree()
end



#TODO
function sample_iid!(variational::TreeReference, replica, shared)
    for var_name in continuous_variables(replica.state)
        for i in eachindex(variational.mean[var_name])
            val = randn(replica.rng) * variational_standard
end


function (variational::TreeReference)(state)
    log_pdf = 0.0

    marginal_var_name = continuous_variables(state)[1]
    marginal_state = variable(state, marginal_var_name)
    marginal_mean = variational.means[marginal_var_name]
    marginal_standard_deviation = variational.standard_deviations[marginal_var_name]
    log_pdf += logpdf(Normal(marginal_mean, marginal_standard_deviation), marginal_state)

     for edges in variational.edges
        parent_var_name = edges[1]
        child_var_name = edges[2]

        state_at_parent = variable(state, parent_var_name)
        state_at_child = variable(state, child_var_name)

        log_pdf += tree_logdensity(variational, child_var_name, parent_var_name, state_at_child, state_at_parent)
    end
    return log_pdf
end


function tree_logdensity(variational::TreeReference, child_var_name, parent_var_name, state_at_child, state_at_parent)
    child_mean = variational.means[child_var_name]
    parent_mean = variational.means[parent_var_name]
    child_standard_deviation = variational.standard_deviations[child_var_name]
    parent_standard_deviation = variational.standard_deviations[child_var_name]

    rho = get_rho(parent_var_name, child_var_name)

    new_mu = child_mean + rho * (child_standard_deviation / parent_standard_deviation) * (state_at_parent - parent_mean)
    new_sigma = sqrt((1-rho^2) * (child_standard_deviation)^2)

    logdensity = logpdf(Normal(new_mu, new_sigma), state_at_child)

    return logdensity
end

#TODO
function get_rho(var_name1, var_name2)
end



# LogDensityProblemsAD implementation (currently only for special case of a singleton variable)
#TODO
LogDensityProblems.logdensity(log_potential::TreeReference, x)
#TODO
function LogDensityProblems.dimension(log_potential::TreeReference)
end
#TODO
LogDensityProblemsAD.ADgradient(kind::ADTypes.AbstractADType. log_potential::TreeReference, replica::Replica)
#TODO
function LogDensityProblems.logdensity_and_gradient(log_potential::BufferedAD{TreeReference}, x)
end