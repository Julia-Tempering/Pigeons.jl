using Turing
using SplittableRandoms
using Pigeons

include("../src/examples/turing.jl")

model = Pigeons.flip_model_unidentifiable()
inputs = Inputs(
    target = TuringLogPotential(model),
    n_chains = 0,
    n_chains_var_reference = 10,
    var_reference = GaussianReference(),
    seed = 1
)
pt = pigeons(inputs)
println(1+1)