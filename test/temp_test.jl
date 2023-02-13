using Pigeons
using Turing
include("../src/examples/turing.jl")

model = Pigeons.flip_model_unidentifiable()
inputs = Inputs(
    target = TuringLogPotential(model),
    n_chains = 10,
    n_chains_var_reference = 0,
    seed = 1
)

pt = pigeons(inputs)
println(1+1)