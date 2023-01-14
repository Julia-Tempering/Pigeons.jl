using Distributions 
using ConcreteStructs
using DynamicPPL
# using BenchmarkTools
using Pigeons

h = Pigeons.SliceSampler()
include("../src/pt/turing_test.jl")
log_potential = Pigeons.TuringLogPotential(model)
println(vi.metadata[1].vals)

function main()
    for i in 1:100
        Pigeons.slice_sample!(h, vi, log_potential)
        println(vi.metadata[1].vals)
    end
end

main()
# @btime main()

