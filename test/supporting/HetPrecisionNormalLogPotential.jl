struct HetPrecisionNormalLogPotential 
    precisions::Vector{Float64}
end
HetPrecisionNormalLogPotential(dim::Int) = HetPrecisionNormalLogPotential(ones(dim))

Pigeons.create_reference_log_potential(
    target::HetPrecisionNormalLogPotential, ::Inputs) = 
        target

Pigeons.create_state_initializer(my_potential::HetPrecisionNormalLogPotential, ::Inputs) = my_potential
Pigeons.initialization(target::HetPrecisionNormalLogPotential, ::SplittableRandom, ::Int) = zeros(length(target.precisions))
    
function Pigeons.sample_iid!(my_potential::HetPrecisionNormalLogPotential, replica)
    d = length(replica.state)
    @assert d == length(my_potential.precisions)
    for i in 1:d 
        replica.state[i] = randn(replica.rng) / sqrt(my_potential.precisions[i])
    end
end

function Pigeons.gradient!!(log_potential::HetPrecisionNormalLogPotential, x::T, buffer::T) where {T}
    len = length(x)
    @assert len == length(log_potential.precisions) 
    @assert len == length(buffer)
    buffer .= -log_potential.precisions .* x
    return buffer
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