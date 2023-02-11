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
    if DISCRETE_VARS[] != [] error("Updating a Gaussian reference with discrete variables.") end
    for var_name in CONTINUOUS_VARS[]
        var_reference.μ[var_name] = get_statistic(reduced_recorders, var_name, Mean)
        var_reference.σ[var_name] = sqrt.(get_statistic(reduced_recorders, var_name, Variance))
    end
    println("mu")
    println(var_reference.μ) # debug
    println("sigma")
    println(var_reference.σ) # debug
end

function sample_iid!(var_reference::GaussianReference, replica)
    for var_name in CONTINUOUS_VARS[]
        for i in eachindex(var_reference.μ[var_name])
            val = rand(replica.rng, Normal(var_reference.μ[var_name][i], var_reference.σ[var_name][i]))
            update_state!(replica.state, var_name, i, val)
        end
    end
end

function (var_reference::GaussianReference)(state)
    log_pdf = 0.0
    for var_name in CONTINUOUS_VARS[]
        var = variable(state, var_name)
        for i in eachindex(var)
            log_pdf += logpdf(Normal(var_reference.μ[var_name][i], var_reference[var_name][i]), var[i])
        end 
    end
    return log_pdf
end