# DELETE THIS FILE LATER
include("../src/Pigeons.jl")
using .Pigeons
using BenchmarkTools
using Distributions

function main()
    potential(x) = -logpdf(Normal(0.0, 1.0), x[1])
    h = Pigeons.SS(potential)
    out = Pigeons.slice_sample(h, [0.0], 100)
end

@btime main()
