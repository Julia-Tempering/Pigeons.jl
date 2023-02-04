"""
A Gaussian mean-field variational reference (i.e., with a diagonal covariance matrix).
"""
@kwdef mutable struct GaussianReference <: VarReference
    μ::Dict{Symbol, Any} = Dict{Symbol, Any}() # means
    σ::Dict{Symbol, Any} = Dict{Symbol, Any}() # standard deviations
    
    function GaussianReference(μ, σ)
        @assert length(μ) == length(σ)
        new(μ, σ)
    end
end

dim(var_reference::GaussianReference) = length(var_reference.μ)
activate_var_reference(::GaussianReference, iterators::Iterators) = iterators.round ≥ 6 ? true : false
var_reference_recorder_builders(::GaussianReference) = [target_online]

function update_reference!(reduced_recorders, var_reference::GaussianReference)
    for var_name in CONTINUOUS_VARIABLES
        var_reference.μ[var_name] = get_statistic(reduced_recorders, var_name, Mean)
        var_reference.σ[var_name] = sqrt.(get_statistic(reduced_recorders, var_name, Variance))
    end
end

function sample_iid!(state, var_reference::GaussianReference)
    for var_name in CONTINUOUS_VARIABLES
        for i in eachindex(var_reference.μ[var_name])
            val = Normal(var_reference.μ[var_name][i], var_reference.σ[var_name][i])
            update_state!(state, var_name, i, val)
        end
    end
end