using Pidgeons
using Test
using Distributions
using Random

@testset "Pidgeons.jl" begin
    # Write your tests here
end

@testset "Basic NRPT test (normal distribution)" begin
    Random.seed!(2340981)
    N = 2
    InitialState = [[5.0] for _ in 1:(N+1)]
    ntotal = 200
    V_0(θ) = -logpdf(Normal(10.0, 1.0), θ[1])
    prior_sampler() = [rand(Normal(10.0, 1.0))]
    V_1(θ) = -logpdf(Normal(0.0, 1.0), θ[1])
    out = Pidgeons.NRPT(V_0, V_1, InitialState, ntotal, N, optimreference = false, prior_sampler = prior_sampler).States
    final_states = map((i) -> out[i][end], 1:length(out))
    final_mean = mean(final_states)[1]
    @test (final_mean < 0.5) && (final_mean > -0.5)
end

