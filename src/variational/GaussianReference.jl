"""
A Gaussian mean-field variational reference (i.e., with a diagonal covariance matrix).
"""
@kwdef mutable struct GaussianReference 
    mean::Dict{Symbol, Any} = Dict{Symbol, Any}() 
    standard_deviation::Dict{Symbol, Any} = Dict{Symbol, Any}() 
    first_tuning_round::Int = 6 # TODO: this should be moved elsewhere?

    function GaussianReference(mean, standard_deviation, first_tuning_round)
        @assert length(mean) == length(standard_deviation)
        @assert first_tuning_round ≥ 1
        new(mean, standard_deviation, first_tuning_round)
    end
end

dim(variational::GaussianReference) = length(variational.mean)
function activate_variational(variational::GaussianReference, iterators::Iterators) 
    iterators.round ≥ variational.first_tuning_round ? true : false
end
variational_recorder_builders(::GaussianReference) = [_transformed_online]

function update_reference!(reduced_recorders, variational::GaussianReference, state)
    if discrete_variables(state) != [] error("Updating a Gaussian reference with discrete variables.") end
    for var_name in continuous_variables(state)
        variational.mean[var_name] = get_transformed_statistic(reduced_recorders, var_name, Mean)
        variational.standard_deviation[var_name] = sqrt.(get_transformed_statistic(reduced_recorders, var_name, Variance))
    end
end

function sample_iid!(variational::GaussianReference, replica, shared)
    for var_name in continuous_variables(replica.state)
        for i in eachindex(variational.mean[var_name])
            val = randn(replica.rng) * variational.standard_deviation[var_name][i] + variational.mean[var_name][i]
            update_state!(replica.state, var_name, i, val)
        end
    end
end

function (variational::GaussianReference)(state)
    log_pdf = 0.0
    for var_name in continuous_variables(state)
        log_pdf += gaussian_logdensity(variable(state, var_name), variational.mean[var_name], variational.standard_deviation[var_name])
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
    variational = log_potential.enclosed
    buffer = log_potential.buffer
    mean = variational.mean[:singleton_variable] 
    standard_deviation = variational.standard_deviation[:singleton_variable]
    @. buffer = - 1.0/(standard_deviation^2) * (x - mean)
    return LogDensityProblems.logdensity(variational, x), buffer
end