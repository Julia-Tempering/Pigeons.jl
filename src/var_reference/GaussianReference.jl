"""
A Gaussian mean-field variational reference (i.e., with a diagonal covariance matrix).
"""
@kwdef mutable struct GaussianReference <: VarReference
    mean::Dict{Symbol, Any} = Dict{Symbol, Any}() # means
    standard_deviation::Dict{Symbol, Any} = Dict{Symbol, Any}() # standard deviations
    
    function GaussianReference(mean, standard_deviation)
        @assert length(mean) == length(standard_deviation)
        new(mean, standard_deviation)
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
            val = rand(replica.rng, Normal(var_reference.mean[var_name][i], var_reference.standard_deviation[var_name][i]))
            update_state!(replica.state, var_name, i, val)
        end
    end
end

function (var_reference::GaussianReference)(state)
    log_pdf = 0.0
    for var_name in CONTINUOUS_VARS[]
        var = variable(state, var_name)
        for i in eachindex(var)
            log_pdf += logpdf(Normal(var_reference.mean[var_name][i], var_reference[var_name][i]), var[i])
        end 
    end
    return log_pdf
end