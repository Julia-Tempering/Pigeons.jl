"""
A Gaussian mean-field variational reference (i.e., with a diagonal covariance matrix).
"""
@kwdef mutable struct GaussianReference <: VarReference
    mean::Dict{Symbol, Any} = Dict{Symbol, Any}() 
    standard_deviation::Dict{Symbol, Any} = Dict{Symbol, Any}() 
    first_tuning_round::Int = 6 # TODO: this should be moved elsewhere?

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
        log_pdf += gaussian_logdensity(variable(state, var_name), var_reference.mean[var_name], var_reference.standard_deviation[var_name])
    end
    return log_pdf
end

function gaussian_logdensity(x, mean, standard_deviation)
    log_pdf = 0.0
    for i in eachindex(x)
        log_pdf += -0.5 * log(2.0*pi*standard_deviation[i]^2) - 1.0/(2.0*standard_deviation[i]^2) * (x[i] - mean[i])^2
    end 
    return log_pdf
end

# LogDensityProblemsAD implementation (currently only for special case of a singleton variable)

LogDensityProblems.logdensity(log_potential::GaussianReference, x) = 
    gaussian_logdensity(x, log_potential.mean[:singleton_variable], log_potential.standard_deviation[:singleton_variable])

function LogDensityProblems.dimension(log_potential::GaussianReference) 
    @assert length(log_potential.mean) == 1 && haskey(log_potential.mean, :singleton_variable) "Differentiation of GaussianReference assuming a single flat vector called :singleton_variable at the moment. Found: $(keys(log_potential.mean))"
    return length(log_potential.mean[:singleton_variable])
end

LogDensityProblemsAD.ADgradient(::Symbol, log_potential::GaussianReference, buffers::Augmentation) = 
    BufferedAD(log_potential, buffers)

function LogDensityProblems.logdensity_and_gradient(log_potential::BufferedAD{GaussianReference}, x)
    var_reference = log_potential.enclosed
    buffer = log_potential.buffer
    mean = var_reference.mean[:singleton_variable] 
    standard_deviation = var_reference.standard_deviation[:singleton_variable]
    @. buffer = - 1.0/(standard_deviation^2) * (x - mean)
    return LogDensityProblems.logdensity(var_reference, x), buffer
end