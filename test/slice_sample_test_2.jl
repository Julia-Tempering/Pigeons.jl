using Distributions 
using ConcreteStructs
using DynamicPPL
# using BenchmarkTools
using Pigeons
using SplittableRandoms
using BenchmarkTools

h = Pigeons.SliceSampler()
include("../src/pt/turing_test.jl")
log_potential = Pigeons.TuringLogPotential(model)
println(vi.metadata[1].vals)

rng = SplittableRandom(1)
N = 10000
states = Vector{Float64}(undef, N)

function main()
    for i in 1:N
        Pigeons.slice_sample!(h, vi, log_potential, rng)
        DynamicPPL.invlink!!(vi, model)
        # println([vi.metadata[1].vals, vi.metadata[2].vals])
        # println(vi.metadata[1].vals)
        states[i] = vi.metadata[1].vals[1]
        DynamicPPL.link!(vi, DynamicPPL.SampleFromPrior())
    end
end

main()
println(mean(states))
println(std(states))
# @btime main()


