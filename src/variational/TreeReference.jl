"""
A Gaussian tree variational reference
"""

@kwdef mutable struct TreeReference
    edge_set::Vector{Any} = Vector{Any}()
    mean::Vector{Any} = Vector{Any}()
    standard_deviation::Vector{Any} = Vector{Any}()
    which_variable::Vector{Any} = Vector{Any}()
    which_index::Vector{Int} = Vector{Int}()
    iid_sample_set::Vector{Any} = Vector{Int}()
    first_tuning_round::Int = 6

    function TreeReference(edge_set, mean, standard_deviation, which_variable, which_index, iid_sample_set, first_tuning_round)
        @assert first_tuning_round ≥ 1
        new(edge_set, mean, standard_deviation, which_variable, which_index, iid_sample_set, first_tuning_round)
    end
end


dim(variational::TreeReference) = length(variational.mean)
function activate_variational(variational::TreeReference, iterators)
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
    total_number_of_nodes = length(variational.mean)

    variational.iid_sample_set = zeros(total_number_of_nodes)

    adjacency_list::Dict{Any, Any} = Dict{Any, Vector{Any}}()
    for i in 1:total_number_of_nodes
        adjacency_list[i] = Vector{Any}()
    end 

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
    mst = Vector{Any}()
    pq = BinaryMaxHeap{Any}()
    visited_nodes = Set{Any}()
    
    push!(visited_nodes, root)
    for edge in adjacency_list[root]
        push!(pq, edge)
    end
    
    while !isempty(pq) && length(mst)<total_number_of_nodes-1
        popped = pop!(pq)

        if !(popped[3] in visited_nodes)
            push!(visited_nodes, popped[3])
            push!(mst, popped)

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
    marginal_val = randn(replica.rng) * variational.standard_deviation[1] + variational.mean[1]
    variational.iid_sample_set[1] = marginal_val
    update_state!(replica.state, variational.which_variable[1], 1, marginal_val)

    for edge in variational.edge_set
        params = tree_logdensity(variational, edge[3], edge[2], variational.iid_sample_set[edge[2]]) #TODO
        val = rand(replica.rng) * params[2] + params[1]
        variational.iid_sample_set[edge[3]] = val

        update_state!(replica.state, variational.which_variable[edge[3]], variational.which_index[edge[3]], val)
    end
end


function (variational::TreeReference)(state)
    log_pdf = 0.0

    marginal_state = variable(state, variational.which_variable[1])[1]
    marginal_mean = variational.mean[1]
    marginal_standard_deviation = variational.standard_deviation[1]
    log_pdf += logpdf(Normal(marginal_mean, marginal_standard_deviation), marginal_state)[1]

    for edge in variational.edge_set
        parent_var_name = variational.which_variable[edge[2]]
        child_var_name = variational.which_variable[edge[3]]

        state_at_parent = variable(state, parent_var_name)[variational.which_index[edge[2]]]
        state_at_child = variable(state, child_var_name)[variational.which_index[edge[3]]]

        cond_params = tree_logdensity(variational, edge[3], edge[2], state_at_parent)
        log_pdf += logpdf(Normal(cond_params[1], cond_params[2]), state_at_child)
    end
    return log_pdf
end


function tree_logdensity(variational::TreeReference, child_num, parent_num, state_at_parent)
    child_mean = variational.mean[child_num]
    parent_mean = variational.mean[parent_num]
    child_standard_deviation = variational.standard_deviation[child_num]
    parent_standard_deviation = variational.standard_deviation[parent_num]

    rho = get_rho(parent_num, child_num)

    new_mu = child_mean + rho * (child_standard_deviation / parent_standard_deviation) * (state_at_parent .- parent_mean)
    new_sigma = sqrt((1-rho^2) * (child_standard_deviation)^2)

    return (new_mu, new_sigma)
end

#TODO
function get_rho(parent_num, child_num)
    return 0
end



# LogDensityProblemsAD implementation (currently only for special case of a singleton variable)
#TODO
LogDensityProblems.logdensity(log_potential::TreeReference, x) = 0

#TODO
function LogDensityProblems.dimension(log_potential::TreeReference)
    @assert length(log_potential.mean) == 1 && haskey(log_potential.mean, :singleton_variable) "Differentiation of TreeReference assuming a single flat vector called :singleton_variable at the moment. Found: $(keys(log_potential.mean))"
end

LogDensityProblemsAD.ADgradient(kind::ADTypes.AbstractADType, log_potential::TreeReference, replica::Replica) =
    BufferedAD(log_potential, replica.recorders.buffers)

#TODO
function LogDensityProblems.logdensity_and_gradient(log_potential::BufferedAD{TreeReference}, x)
    variational = log_potential.enclosed
    buffer = log_potential.buffer
    mean = variational.mean[:singleton_variable]
    standard_deviation = variational.standard_deviation[:singleton_variable]
    @. buffer = - 1.0/(standard_deviation^2) * (x - mean)
    return LogDensityProblems.logdensity(variational, x), buffer
end