struct HetPrecisionNormalLogPotential 
    precisions::Vector{Float64}
end
HetPrecisionNormalLogPotential(dim::Int) = HetPrecisionNormalLogPotential(ones(dim))

Pigeons.default_reference(
    target::HetPrecisionNormalLogPotential) = 
        target

Pigeons.initialization(target::HetPrecisionNormalLogPotential, ::AbstractRNG, ::Int) = zeros(length(target.precisions))
    
function Pigeons.sample_iid!(my_potential::HetPrecisionNormalLogPotential, replica)
    d = length(replica.state)
    @assert d == length(my_potential.precisions)
    for i in 1:d 
        replica.state[i] = randn(replica.rng) / sqrt(my_potential.precisions[i])
    end
end

function (log_potential::HetPrecisionNormalLogPotential)(x) 
    len = length(x)
    @assert len == length(log_potential.precisions)
    sum = 0.0
    for i in 1:len 
        sum += log_potential.precisions[i] * x[i]^2
    end
    -0.5 * sum
end

LogDensityProblems.logdensity(log_potential::HetPrecisionNormalLogPotential, x) = log_potential(x) 
LogDensityProblems.dimension(log_potential::HetPrecisionNormalLogPotential) = length(log_potential.precisions)
LogDensityProblemsAD.ADgradient(kind::Symbol, log_potential::HetPrecisionNormalLogPotential, buffers::Pigeons.Augmentation) = 
    LogDensityProblemsAD.ADgradient(kind, log_potential)