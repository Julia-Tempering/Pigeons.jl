"""
A Gaussian dense variational reference (i.e., with a dense covariance matrix).
"""
@kwdef mutable struct DenseGaussianReference 
    mean::Vector{Any} = Vector{Any}() 
    covariance::Matrix{Float64} = zeros(Float64, 0, 0)
    precision::Matrix{Float64} = zeros(Float64, 0, 0)
    cholesky::Any = zeros(Float64, 0, 0)
    which_variable::Vector{Any} = Vector{Any}()
    which_index::Vector{Int} = Vector{Int}()
    identity_gaussian::Any = zeros(Float64, 0, 0)
    first_tuning_round::Int = 10 # TODO: this should be moved elsewhere?

    function DenseGaussianReference(mean, covariance, precision, cholesky, which_variable, which_index, identity_gaussian, first_tuning_round)
        @assert first_tuning_round ≥ 1
        new(mean, covariance, precision, cholesky, which_variable, which_index, identity_gaussian, first_tuning_round)
    end
end

dim(variational::DenseGaussianReference) = length(variational.mean)
function activate_variational(variational::DenseGaussianReference, iterators::Iterators) 
    iterators.round ≥ variational.first_tuning_round ? true : false
end
variational_recorder_builders(::DenseGaussianReference) = [_transformed_online_full]

function update_reference!(reduced_recorders, variational::DenseGaussianReference, state)
    isempty(discrete_variables(state)) || error("Updating a Gaussian reference with discrete variables.")

    empty!(variational.which_variable)
    empty!(variational.which_index)
    empty!(variational.mean)
    empty!(variational.which_variable)
    empty!(variational.which_index)

    eps = 1e-6
    temp_covariance = get_transformed_statistic(reduced_recorders, :singleton_variable, CovMatrix)
    variational.covariance = temp_covariance + eps * I

    variational.mean = get_transformed_statistic(reduced_recorders, :singleton_variable, Mean)
    variational.identity_gaussian = MvNormal(zeros(length(variational.mean)), I)
    variational.precision = inv(variational.covariance)
    variational.cholesky = cholesky(variational.covariance).L

    for var_name in continuous_variables(state)
        for i = 1:length(variable(state, var_name))
            push!(variational.which_variable, var_name)
            push!(variational.which_index, i)
        end
    end

end

function sample_iid!(variational::DenseGaussianReference, replica, shared)
    z = rand(variational.identity_gaussian)
    sample = variational.mean + variational.cholesky * z

    for i = 1:length(variational.mean)
        update_state!(replica.state, variational.which_variable[i], variational.which_index[i], sample[i])
    end
end

function (variational::DenseGaussianReference)(state)
    flattened_state = Vector{Float64}()

    for i = 1:length(variational.mean)
        name = variational.which_variable[i]
        index = variational.which_index[i]
        push!(flattened_state, Pigeons.variable(state, name)[index])
    end

    return -0.5 * (transpose(flattened_state - variational.mean) * variational.precision * (flattened_state - variational.mean))
end



# LogDensityProblemsAD implementation (currently only for special case of a singleton variable)

LogDensityProblems.logdensity(log_potential::DenseGaussianReference, x) =
    log_potential(x)

function LogDensityProblems.dimension(log_potential::DenseGaussianReference) 
    return length(log_potential.mean)
end

LogDensityProblemsAD.ADgradient(kind::ADTypes.AbstractADType, log_potential::DenseGaussianReference, replica::Replica) = 
    BufferedAD(log_potential, replica.recorders.buffers)

function LogDensityProblems.logdensity_and_gradient(log_potential::BufferedAD{DenseGaussianReference}, x)
    variational = log_potential.enclosed
    buffer = log_potential.buffer
    mean = variational.mean
    precision = variational.precision
    buffer .= -precision * (x - mean)
    return LogDensityProblems.logdensity(variational, x), buffer
end