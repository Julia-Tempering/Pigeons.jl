"""
A Gaussian tree variational reference
"""

@kwdef mutable struct TreeReference
    edge_set::Vector{Tuple{Float64, Float64, Int, Int}} = Vector{Tuple{Float64, Float64, Int, Int}}()
    mean::Vector{Float64} = Vector{Float64}()
    standard_deviation::Vector{Float64} = Vector{Float64}()
    which_variable::Vector{Symbol} = Vector{Symbol}()
    which_index::Vector{Int} = Vector{Int}()
    iid_sample_set::Vector{Float64} = Vector{Float64}()
    covariance_matrix::Matrix{Float64} = zeros(Float64, 0, 0)
    first_tuning_round::Int = 10
    
    function TreeReference(edge_set, mean, standard_deviation, which_variable, which_index, iid_sample_set, covariance_matrix, first_tuning_round)
        @assert first_tuning_round ≥ 1
        new(edge_set, mean, standard_deviation, which_variable, which_index, iid_sample_set, covariance_matrix, first_tuning_round)
    end
end


dim(variational::TreeReference) = length(variational.mean)
function activate_variational(variational::TreeReference, iterators)
    iterators.round ≥ variational.first_tuning_round ? true : false
end

variational_recorder_builders(::TreeReference) = [_transformed_online_full]


function update_reference!(reduced_recorders, variational::TreeReference, state)
    isempty(discrete_variables(state)) || error("Updating a Gaussian reference with discrete variables.")

    empty!(variational.mean)
    empty!(variational.standard_deviation)
    empty!(variational.which_variable)
    empty!(variational.which_index)
    variational.edge_set = []

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

    adjacency_list::Dict{Int, Vector{Tuple{Float64, Float64, Int, Int}}} = Dict{Int, Vector{Tuple{Float64, Float64, Int, Int}}}()
    for i in 1:total_number_of_nodes
        adjacency_list[i] = Vector{Tuple{Float64, Float64, Int, Int}}()
    end 

    variational.covariance_matrix = get_transformed_statistic(reduced_recorders, :singleton_variable, CovMatrix)

    for i = 1:total_number_of_nodes
        for j = (i+1):total_number_of_nodes
            normalization = (variational.standard_deviation[i] * variational.standard_deviation[j])
            rho = variational.covariance_matrix[i,j] / normalization
            rho = clamp(rho, -0.99, 0.99)
            I = -0.5*log(1-rho^2)
                
            push!(adjacency_list[i], (I, rho, i, j))
            push!(adjacency_list[j], (I, rho, j, i))
        end
    end
    root = 1
    variational.edge_set = directed_max_tree(adjacency_list, root)

    empty!(adjacency_list)
end



function directed_max_tree(adjacency_list, root)
    total_number_of_nodes = length(keys(adjacency_list))
    mst = Vector{Tuple{Float64, Float64, Int, Int}}()
    pq = BinaryMaxHeap{Tuple{Float64, Float64, Int, Int}}()
    visited_nodes = Set{Int}()
    
    push!(visited_nodes, root)
    for edge in adjacency_list[root]
        push!(pq, edge)
    end
    
    while !isempty(pq) && length(mst)<total_number_of_nodes-1
        popped = pop!(pq)

        if !(popped[4] in visited_nodes)
            push!(visited_nodes, popped[4])
            push!(mst, popped)

            for new_edge in adjacency_list[popped[4]]
                if !(new_edge[4] in visited_nodes)
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
        parent_idx = edge[3]
        child_idx = edge[4]

        mu, sigma = tree_logdensity(variational, child_idx, parent_idx, variational.iid_sample_set[parent_idx], edge[2])
        val = randn(replica.rng) * sigma + mu
        variational.iid_sample_set[child_idx] = val

        update_state!(replica.state, variational.which_variable[child_idx], variational.which_index[child_idx], val)
    end
end


function (variational::TreeReference)(state)
    log_pdf = 0.0

    marginal_state = variable(state, variational.which_variable[1])[1]
    marginal_mean = variational.mean[1]
    marginal_standard_deviation = variational.standard_deviation[1]
    log_pdf += Distributions.logpdf(Distributions.Normal(marginal_mean, marginal_standard_deviation), marginal_state)

    for edge in variational.edge_set
        child_idx = edge[4]
        parent_idx = edge[3]

        parent_var_name = variational.which_variable[parent_idx]
        child_var_name = variational.which_variable[child_idx]

        state_at_parent = variable(state, parent_var_name)[variational.which_index[parent_idx]]
        state_at_child = variable(state, child_var_name)[variational.which_index[child_idx]]

        mu, sigma = tree_logdensity(variational, child_idx, parent_idx, state_at_parent, edge[2])
        log_pdf += Distributions.logpdf(Distributions.Normal(mu, sigma), state_at_child)
    end
    return log_pdf
end


function tree_logdensity(variational::TreeReference, child_num, parent_num, state_at_parent, rho)
    child_mean = variational.mean[child_num]
    parent_mean = variational.mean[parent_num]
    child_standard_deviation = variational.standard_deviation[child_num]
    parent_standard_deviation = variational.standard_deviation[parent_num]

    new_mu = child_mean + rho * (child_standard_deviation / parent_standard_deviation) * (state_at_parent - parent_mean)
    new_sigma = sqrt((1-rho^2) * (child_standard_deviation)^2)

    return (new_mu, new_sigma)
end

function tree_gradient(variational::TreeReference, state)
    gradient = zeros(length(variational.mean))

    marginal_state = variable(state, variational.which_variable[1])[1]
    marginal_mean = variational.mean[1]
    marginal_standard_deviation = variational.standard_deviation[1]
    gradient[1] = -(marginal_state - marginal_mean) / marginal_standard_deviation^2

    for edge in variational.edge_set
        child_idx = edge[4]
        parent_idx = edge[3]

        parent_var_name = variational.which_variable[parent_idx]
        child_var_name = variational.which_variable[child_idx]

        state_at_parent = variable(state, parent_var_name)[variational.which_index[parent_idx]]
        state_at_child = variable(state, child_var_name)[variational.which_index[child_idx]]

        mu, sigma = tree_logdensity(variational, child_idx, parent_idx, state_at_parent, edge[2])
        delta = -(state_at_child - mu) / sigma^2

        gradient[child_idx] += delta
        gradient[parent_idx] += delta * (edge[2] * variational.standard_deviation[child_idx] / variational.standard_deviation[parent_idx])
    end
    return gradient
end



# LogDensityProblemsAD implementation (currently only for special case of a singleton variable)

LogDensityProblems.logdensity(log_potential::TreeReference, x) =
    log_potential(x)

function LogDensityProblems.dimension(log_potential::TreeReference)
    dim = length(log_potential.edge_set) + 1
    return dim
end

LogDensityProblemsAD.ADgradient(kind::ADTypes.AbstractADType, log_potential::TreeReference, replica::Replica) = 
    BufferedAD(log_potential, replica.recorders.buffers)

function LogDensityProblems.logdensity_and_gradient(log_potential::BufferedAD{TreeReference}, x)
    variational = log_potential.enclosed
    buffer = log_potential.buffer
    buffer .= tree_gradient(variational, x)
    return LogDensityProblems.logdensity(variational, x), buffer
end