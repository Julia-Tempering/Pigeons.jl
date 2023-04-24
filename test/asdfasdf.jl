using Pigeons 
using Distributions
using DynamicPPL

include("turing.jl")

model = flip_model_unidentifiable()
inputs = Inputs(
    target = TuringLogPotential(model),
    n_chains = 10,
    n_chains_var_reference = 0,
    var_reference = NoVarReference(),
    seed = 1
)
pt = pigeons(inputs)
nothing