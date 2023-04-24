using Pigeons 
using Distributions
using DynamicPPL
using LinearAlgebra
using OnlineStats
using Random
using Serialization
using SplittableRandoms
using Statistics
using Test

include("turing.jl")

model = flip_model_unidentifiable()

inputs = Inputs(
    target = TuringLogPotential(model),
    n_chains = 5,
    n_chains_var_reference = 5,
    var_reference = GaussianReference(),
    seed = 1
)
pt = pigeons(inputs)
println(1+1)