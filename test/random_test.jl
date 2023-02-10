using Turing
using SplittableRandoms
using Pigeons

include("../src/examples/turing.jl")

model = Pigeons.flip_model_unidentifiable()
inputs = Inputs(
    target =  toy_mvn_target(1),
    n_chains = 10,
    n_chains_var_reference = 0,
    seed = 1
)
pt = pigeons(inputs)
println(1+1)