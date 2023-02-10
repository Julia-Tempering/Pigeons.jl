using Pigeons

include("../src/examples/vector.jl")

target = VectorLogPotential(
    Normal_2D,
    Normal_2D_reference,
    Normal_2D_reference_sample!,
    2
)

inputs = Inputs(
    target =  target,
    n_chains = 10,
    n_chains_var_reference = 0,
    seed = 1
)
pt = pigeons(inputs)
println(1+1)
