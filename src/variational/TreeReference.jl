"""
A Gaussian tree variational reference
"""

import Pkg
Pkg.add("DataStructures")
using DataStructures

@kwdef mutable struct TreeReference
    edge_set::Vector{Any} = Vector{Any}()
    mean::Dict{Tuple{Symbol, Vector{Any}}} = Dict{Symbol, Vector{Any}}()
    standard_deviation::Dict{Symbol, Vector{Any}} = Dict{Symbol, Vector{Any}}()
    which_variable::Vector{Symbol}
    which_index::Vector{Int}
    first_tuning_round::Int = 6

    function TreeReference(edge_set, mean, standard_deviation, which_variable, which_index, first_tuning_round)
        @assert first_tuning_round ≥ 1
        new(edge_set, mean, standard_deviation, which_variable, which_index, first_tuning_round)
    end
end


dim(variational::TreeReference) = length(variational.mean)
function activate_variational(variational::TreeReference, iterators::Iterators)
    iterators.round ≥ variational.first_tuning_round ? true : false
end

variational_recorder_builders(::TreeReference) = [_transformed_online]


function update_reference!(reduced_recorders, variational::TreeReference, state)
    isempty(discrete_variables(state)) || error("Updating a Gaussian reference with discrete variables.")
    
    for var_name in continuous_variables(state)
        temp_mean = get_transformed_statistic(reduced_recorders, var_name, Mean)
        temp_std = sqrt.(get_transformed_statistic(reduced_recorders, var_name, Variance))

        dimension = length(temp_mean)
        for i = 1:dimension
            push!(variational.mean, temp_mean[i])
            push!(variational.standard_deviation, temp_std[i])

            push!(variational.which_variable, var_name)
            push!(variational.which_index, i)
        end
    end
    @assert length(variational.mean) == length(variational.standard_deviation)

    adjacency_list::Dict{Symbol, Vector{Any}} = Dict{Symbol, Vector{Any}}()

    total_number_of_nodes = length(variational.mean)
    for i = 1:total_number_of_nodes
        for j = 1:total_number_of_nodes
            if i != j
                I = compute_mutual_info(i, j)

                push!(adjacency_list[i], (I, i, j))
                push!(adjacency_list[j], (I, j, i))
            end
        end
    end
    root = 1
    variational.edge_set = directed_max_tree(adjacency_list, root)
end


function compute_mutual_info(i, j)
    return -0.5*log(1-get_rho(i, j)^2)
end


function directed_max_tree(adjacency_list, root)
    total_number_of_nodes = length(keys(adjacency_list))
    mst = Vector{Tuple{Int, Int}}()
    pq = BinaryMaxHeap{Tuple{Float64, Int, Int}}()
    visited_nodes = Set{Int}()
    
    push!(visited_nodes, root)
    for edge in adjacency_list[root]
        push!(pq, edge)
    end
    
    while !isempty(pq) && length(mst)<total_number_of_nodes-1
        popped = pop!(pq)

        if !(popped[3] in visited_nodes)
            push!(visited_nodes, popped[3])
            push!(mst, (popped[2], popped[3]))

            for new_edge in adjacency_list[popped[3]]
                if !(new_edge[3] in visited_nodes)
                    push!(pq, new_edge)
                end
            end
        end
    end
    @assert length(mst) == total_number_of_nodes-1 
    return mst
end


function sample_iid!(variational::TreeReference, replica, shared)
    new_state::Vector{Int} = Vector{Int}()

    marginal_val = randn(replica.rng) * variational.standard_deviation[1] + variational.mean[1]
    push!(new_state, marginal_val)
    update_state!(replica.state, which_variable[1], 1, marginal_val)

    for edge in variational.edge_set
        params = tree_logdensity(variational, which_variable[edge[3]], which_variable[edge[2]], new_state[edge[2]])
        val = rand(replica.rng) * params[2] + params[1]

        update_state!(replica.state, which_variable[edge[3]], which_index[edge[3]], val)
    end
end


function (variational::TreeReference)(state)
    log_pdf = 0.0

    marginal_var_name = continuous_variables(state)[1]
    marginal_state = variable(state, marginal_var_name)
    marginal_mean = variational.mean[marginal_var_name]
    marginal_standard_deviation = variational.standard_deviation[marginal_var_name]
    log_pdf += logpdf(Normal(marginal_mean, marginal_standard_deviation), marginal_state)

    for edge in variational.edge_set
        parent_var_name = which_variable[edge[1]]
        child_var_name = which_variable[edge[2]]

        state_at_parent = variable(state, parent_var_name)
        state_at_child = variable(state, child_var_name)

        cond_params = tree_logdensity(variational, child_var_name, parent_var_name, state_at_parent)
        log_pdf += logpdf(Normal(cond_params[1], cond_params[2]), state_at_child)
    end
    return log_pdf
end


function tree_logdensity(variational::TreeReference, child_var_name, parent_var_name, state_at_parent)
    child_mean = variational.mean[child_var_name]
    parent_mean = variational.mean[parent_var_name]
    child_standard_deviation = variational.standard_deviation[child_var_name]
    parent_standard_deviation = variational.standard_deviation[child_var_name]

    rho = get_rho(parent_var_name, child_var_name)

    new_mu = child_mean + rho * (child_standard_deviation / parent_standard_deviation) * (state_at_parent - parent_mean)
    new_sigma = sqrt((1-rho^2) * (child_standard_deviation)^2)

    return (new_mu, new_sigma)
end

#TODO
function get_rho(var_name1, var_name2)
    return 0
end



# LogDensityProblemsAD implementation (currently only for special case of a singleton variable)
#TODO
LogDensityProblems.logdensity(log_potential::TreeReference, x) = 0

function LogDensityProblems.dimension(log_potential::TreeReference)
    @assert length(log_potential.mean) == 1 && haskey(log_potential.mean, :singleton_variable) "Differentiation of TreeReference assuming a single flat vector called :singleton_variable at the moment. Found: $(keys(log_potential.mean))"
end

LogDensityProblemsAD.ADgradient(kind::ADTypes.AbstractADType. log_potential::TreeReference, replica::Replica) =
    BufferedAD(log_potential, replica.recorders.buffers)

function LogDensityProblems.logdensity_and_gradient(log_potential::BufferedAD{TreeReference}, x)
    variational = log_potential.enclosed
    buffer = log_potential.buffer
    mean = variational.mean[:singleton_variable]
    standard_deviation = variational.standard_deviation[:singleton_variable]
    @. buffer = - 1.0/(standard_deviation^2) * (x - mean)
    return LogDensityProblems.logdensity(variational, x), buffer
end