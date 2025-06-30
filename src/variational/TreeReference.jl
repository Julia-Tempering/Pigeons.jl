"""
A Gaussian tree variational reference
"""

import Pkg
Pkg.add("DataStructures")
using DataStructures

@kwdef mutable struct TreeReference
    edge_set::Vector{Tuple{Float64, Symbol, Symbol}} = Vector{Tuple{Float64, Symbol, Symbol}}()
    mean::Dict{Symbol, Any} = Dict{Symbol, Any}()
    standard_deviation::Dict{Symbol, Any} = Dict{Symbol, Any}()
    first_tuning_round::Int = 6

    function TreeReference(edge_set, mean, standard_deviation, first_tuning_round)
        dim = length(mean)
        @assert length(edge_set)==dim-1 || length(edge_set)==(dim*(dim-1))/2
        @assert first_tuning_round ≥ 1
        new(edge_set, mean, standard_deviation, first_tuning_round)
    end
end


dim(variational::TreeReference) = length(variational.mean)
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


function directed_max_tree(adjacency_list, root)
    total_number_of_nodes = length(keys(adjacency_list))
    mst = Vector{Tuple{Symbol, Symbol}}()
    pq = BinaryMaxHeap{Tuple{Float64, Symbol, Symbol}}()
    visited_nodes = Set{Symbol}()
    push!(visited_nodes, root)

    for edge in adjacency_list[root]
        push!(pq, edge)
    end
    
    while !isempty(pq) && length(mst)<total_number_of_nodes-1
        edge = pop!(pq)

        if !(edge[3] in visited_nodes)
            push!(visited_nodes, edge[3])
            push!(mst, (edge[2], edge[3]))

            for new_edge in adjacency_list[edge[3]]
                if !(new_edge[3] in visited_nodes)
                    push!(pq, new_edge)
                end
            end
        end
    end
    @assert length(mst) == total_number_of_nodes-1 
    return mst
end



#TODO
function sample_iid!(variational::TreeReference, replica, shared)
end


function (variational::TreeReference)(state)
    log_pdf = 0.0

    marginal_var_name = continuous_variables(state)[1]
    marginal_state = variable(state, marginal_var_name)
    marginal_mean = variational.mean[marginal_var_name]
    marginal_standard_deviation = variational.standard_deviation[marginal_var_name]
    log_pdf += logpdf(Normal(marginal_mean, marginal_standard_deviation), marginal_state)

     for edge in variational.edge_set
        parent_var_name = edge[1]
        child_var_name = edge[2]

        state_at_parent = variable(state, parent_var_name)
        state_at_child = variable(state, child_var_name)

        log_pdf += tree_logdensity(variational, child_var_name, parent_var_name, state_at_child, state_at_parent)
    end
    return log_pdf
end


function tree_logdensity(variational::TreeReference, child_var_name, parent_var_name, state_at_child, state_at_parent)
    child_mean = variational.mean[child_var_name]
    parent_mean = variational.mean[parent_var_name]
    child_standard_deviation = variational.standard_deviation[child_var_name]
    parent_standard_deviation = variational.standard_deviation[child_var_name]

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