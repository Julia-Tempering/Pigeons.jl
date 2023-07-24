""" 
$SIGNATURES 

A toy multi-variate normal (mvn) target distribution used for testing. 
Uses a specialized path, [`ScaledPrecisionNormalPath`](@ref), 
such that i.i.d. sampling is possible at all chains (via [`ToyExplorer`](@ref)). 
"""
@provides target toy_mvn_target(dim::Int) = ScaledPrecisionNormalPath(dim) 

initialization(target::ScaledPrecisionNormalPath, rng::AbstractRNG, _::Int64) = 
    randn(rng, target.dim) / sqrt(target.precision1)

default_explorer(::ScaledPrecisionNormalPath) = ToyExplorer()

sample_iid!(log_potential::ScaledPrecisionNormalLogPotential, replica, shared) =
    rand!(replica.rng, replica.state, log_potential)

Random.rand!(rng::AbstractRNG, x::AbstractVector, log_potential::ScaledPrecisionNormalLogPotential) =
    for i in eachindex(x)
        x[i] = randn(rng) / sqrt(log_potential.precision)
    end

Random.rand!(rng::AbstractRNG, state::Pigeons.StanState{Vector{Float64}}, log_potential::Pigeons.ScaledPrecisionNormalLogPotential) = 
    rand!(rng, state.unconstrained_parameters, log_potential)