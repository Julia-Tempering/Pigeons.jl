using Pidgeons
using Test
include("../src/ParallelTempering.jl") # temp
using .ParallelTempering
using Distributions
# using Statistics
# using LinearAlgebra
# using Suppressor
using Distributions
using Random
using ForwardDiff

@testset "Pidgeons.jl" begin
    # Write your tests here
end

@testset "Basic NRPT test (normal distribution)" begin
    N = 2
    InitialState = [[5.0] for _ in 1:(N+1)]
    ntotal = 100
    V_0(θ) = -logpdf(Normal(10.0, 1.0), θ[1])
    prior_sampler() = [rand(Normal(10.0, 1.0))]
    V_1(θ) = -logpdf(Normal(0.0, 1.0), θ[1])
    out = ParallelTempering.NRPT(V_0, V_1, InitialState, ntotal, N, optimreference = false, prior_sampler = prior_sampler).States
    final_states = map((i) -> out[i][end], 1:length(out))
    final_mean = mean(final_states)[1]
    @test (final_mean < 0.2) && (final_mean > -0.2)
end

