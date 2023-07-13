"""
A Gaussian mean-field variational reference (i.e., with a diagonal covariance matrix).
"""
@kwdef mutable struct GaussianReference <: VarReference
    mean::Dict{Symbol, Any} = Dict{Symbol, Any}() 
    standard_deviation::Dict{Symbol, Any} = Dict{Symbol, Any}() 
    first_tuning_round::Int = 6

    function GaussianReference(mean, standard_deviation, first_tuning_round)
        @assert length(mean) == length(standard_deviation)
        @assert first_tuning_round ≥ 1
        new(mean, standard_deviation, first_tuning_round)
    end
end

dim(var_reference::GaussianReference) = length(var_reference.mean)
function activate_var_reference(var_reference::GaussianReference, iterators::Iterators) 
    iterators.round ≥ var_reference.first_tuning_round ? true : false
end
var_reference_recorder_builders(::GaussianReference) = [_transformed_online]

function update_reference!(reduced_recorders, var_reference::GaussianReference, state)
    if discrete_variables(state) != [] error("Updating a Gaussian reference with discrete variables.") end
    for var_name in continuous_variables(state)
        var_reference.mean[var_name] = get_transformed_statistic(reduced_recorders, var_name, Mean)
        var_reference.standard_deviation[var_name] = sqrt.(get_transformed_statistic(reduced_recorders, var_name, Variance))
    end
end

function sample_iid!(var_reference::GaussianReference, replica, shared)
    for var_name in continuous_variables(replica.state)
        for i in eachindex(var_reference.mean[var_name])
            val = randn(replica.rng) * var_reference.standard_deviation[var_name][i] + var_reference.mean[var_name][i]
            update_state!(replica.state, var_name, i, val)
        end
    end
end

function (var_reference::GaussianReference)(state)
    log_pdf = 0.0
    for var_name in continuous_variables(state)
        var = variable(state, var_name)
        for i in eachindex(var)
            mean = var_reference.mean[var_name][i] 
            standard_deviation = var_reference.standard_deviation[var_name][i]
            log_pdf += -0.5 * log(2*pi*standard_deviation^2) - 1/(2*standard_deviation^2) * (var[i] - mean)^2
        end 
    end
    return log_pdf
end

