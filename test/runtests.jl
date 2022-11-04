using Pidgeons
using Test
using ParallelTempering # temp ------ (below, as well)
using Distributions
using Statistics
using LinearAlgebra
using Suppressor
using Distributions
using Random
using ForwardDiff

@testset "Pidgeons.jl" begin
    # Write your tests here.
end

# @testset "Basic NRPT test (normal distribution)" begin
#     N = 2
#     InitialState = [[5.0] for _ in 1:(N+1)]
#     ntotal = 100
#     V_0(θ) = -logpdf(Normal(10.0, 1.0), θ[1])
#     prior_sampler() = rand(Normal(10.0, 1.0))
#     V_1(θ) = -logpdf(Normal(0.0, 1.0), θ[1])
#     out = ParallelTempering.nrpt(V_0, V_1, InitialState, ntotal, N, optimreference = false, prior_sampler = prior_sampler)
#     out.States
# end







# # Start simulation
# seeds = [1949412, 6488888, 6478068, 3204321, 2151793, 4912732, 1522438, 3929444, 3819896, 2023981]
# ParallelTempering.run_simulation(V_0, V_1, InitialState, ntotal, N, prior_sampler, seeds, mod_name, compile=true, n_explore=1, optimreference_start=7, n_reps=10, save_results=true)