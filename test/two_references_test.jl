using Pigeons
using Distributions
using Random
using SplittableRandoms

include("../src/examples/turing.jl")
include("../src/examples/vector.jl")

"""
Run from runtests.jl
"""

model = Pigeons.flip_model_unidentifiable()

inputs = Inputs(
    target = TuringLogPotential(model),
    n_chains = 10,
    n_chains_fixed_reference = 5,
    n_chains_var_reference = 5,
    var_reference = GaussianReference(),
    seed = 1
)
pt = pigeons(inputs)
println(1+1)
