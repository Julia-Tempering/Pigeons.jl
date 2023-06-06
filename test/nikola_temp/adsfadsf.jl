using Pigeons 
using DynamicPPL
using Distributions
include("../supporting/turing_models.jl")

model = flip_model_unidentifiable()
 
# Check NoVarReference()
inputs = Inputs(
    target = TuringLogPotential(model),
    n_chains = 10,
    n_chains_var_reference = 0,
    seed = 1,
    recorder_builders = [traces]
)

pt = pigeons(inputs)
nothing