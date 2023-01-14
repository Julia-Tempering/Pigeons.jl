using Distributions 
using ConcreteStructs
using DynamicPPL
# using BenchmarkTools
using Pigeons
using SplittableRandoms

h = Pigeons.SliceSampler()
include("../src/pt/turing_test.jl")
log_potential = Pigeons.TuringLogPotential(model)
println(vi.metadata[1].vals)

rng = SplittableRandom(1)

function main()
    for i in 1:100
        Pigeons.slice_sample!(h, vi, log_potential, rng)
        println(vi.metadata[1].vals)
    end
end

main()
# @btime main()

