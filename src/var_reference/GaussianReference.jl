"""
A Gaussian mean-field variational reference (i.e., with a diagonal covariance matrix).
"""
@kwdef mutable struct GaussianReference <: VarReference
    μ::Dict{Symbol, Any} = Dict{Symbol, Any}() # means
    σ::Dict{Symbol, Any} = Dict{Symbol, Any}() # standard deviations
    first_tuning_round::Int = 6

    function GaussianReference(μ, σ, first_tuning_round)
        @assert length(μ) == length(σ)
        @assert first_tuning_round ≥ 1
        new(μ, σ, first_tuning_round)
    end
end

dim(var_reference::GaussianReference) = length(var_reference.μ)
function activate_var_reference(var_reference::GaussianReference, iterators::Iterators) 
    iterators.round ≥ var_reference.first_tuning_round ? true : false
end
var_reference_recorder_builders(::GaussianReference) = [_transformed_online]

function update_reference!(reduced_recorders, var_reference::GaussianReference, state)
    if discrete_variables(state) != [] error("Updating a Gaussian reference with discrete variables.") end
    for var_name in continuous_variables(state)
        var_reference.μ[var_name] = get_transformed_statistic(reduced_recorders, var_name, Mean)
        var_reference.σ[var_name] = sqrt.(get_transformed_statistic(reduced_recorders, var_name, Variance))
    end
end

function sample_iid!(var_reference::GaussianReference, replica, shared)
    for var_name in continuous_variables(replica.state)
        for i in eachindex(var_reference.μ[var_name])
            val = randn(replica.rng) * var_reference.σ[var_name][i] + var_reference.μ[var_name][i]
            update_state!(replica.state, var_name, i, val)
        end
    end
end

function (var_reference::GaussianReference)(state)
    log_pdf = 0.0
    for var_name in continuous_variables(state)
        var = variable(state, var_name)
        for i in eachindex(var)
            mean = var_reference.μ[var_name][i] 
            standard_deviation = var_reference.σ[var_name][i]
            log_pdf += -0.5 * log(2*pi*standard_deviation^2) - 1/(2*standard_deviation^2) * (var[i] - mean)^2
        end 
    end
    return log_pdf
end