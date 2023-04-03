"""
A Gaussian mean-field variational reference (i.e., with a diagonal covariance matrix).
"""
@kwdef mutable struct GaussianReference{T} <: VarReference
    mean::Dict{Symbol, T} = Dict{Symbol, T}() # means
    standard_deviation::Dict{Symbol, T} = Dict{Symbol, T}() # standard deviations
    
    function GaussianReference(mean::Dict{Symbol, T}, standard_deviation::Dict{Symbol, T}) where T
        @assert length(mean) == length(standard_deviation)
        new{T}(mean, standard_deviation)
    end
end

dim(var_reference::GaussianReference) = length(var_reference.mean)
activate_var_reference(::GaussianReference, iterators::Iterators) = iterators.round ≥ 6 ? true : false
var_reference_recorder_builders(::GaussianReference) = [target_online]

function update_reference!(reduced_recorders, var_reference::GaussianReference)
    if DISCRETE_VARS[] != [] error("Updating a Gaussian reference with discrete variables.") end
    for var_name in CONTINUOUS_VARS[]
        var_reference.mean[var_name] = get_statistic(reduced_recorders, var_name, Mean)
        var_reference.standard_deviation[var_name] = sqrt.(get_statistic(reduced_recorders, var_name, Variance))
    end
end

function sample_iid!(var_reference::GaussianReference, replica)
    for var_name in CONTINUOUS_VARS[]
        for i in eachindex(var_reference.mean[var_name])
            val = randn(replica.rng) * var_reference.standard_deviation[var_name][i] + var_reference.mean[var_name][i]
            update_state!(replica.state, var_name, i, val)
        end
    end
end

function (var_reference::GaussianReference)(state)
    log_pdf = 0.0
    for var_name in CONTINUOUS_VARS[]
        var = variable(state, var_name)
        for i in eachindex(var)
            mean = var_reference.mean[var_name][i] 
            standard_deviation = var_reference.standard_deviation[var_name][i]
            log_pdf += -0.5 * log(2*pi*standard_deviation^2) - 1/(2*standard_deviation^2) * (var[i] - mean)^2
        end 
    end
    return log_pdf
end