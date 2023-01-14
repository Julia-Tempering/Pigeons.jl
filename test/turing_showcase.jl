# using Distributions 
# using ConcreteStructs
# using DynamicPPL
# using BenchmarkTools
using Pigeons
# using SplittableRandoms
# using BenchmarkTools

pigeons(target = toy_mvn_target(100), checked_round = 3)

# pigeons(target = TuringLogPotential(model::DynamicPPL.Model), checked_round = 3)