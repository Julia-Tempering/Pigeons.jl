module PigeonsDynamicPPLExt

using Pigeons
if isdefined(Base, :get_extension)
    using ADTypes
    import DifferentiationInterface as DI
    using Distributions
    using DynamicPPL
    using FillArrays: Zeros
    using LinearAlgebra: I
    using LogDensityProblems
    using LogDensityProblemsAD
    using DocStringExtensions
    using SplittableRandoms
    using Random
else
    using ..ADTypes
    import ..DifferentiationInterface as DI
    using ..Distributions
    using ..DynamicPPL
    using ..FillArrays: Zeros
    using ..LinearAlgebra: I
    using ..LogDensityProblems
    using ..LogDensityProblemsAD
    using ..DocStringExtensions
    using ..SplittableRandoms
    using ..Random
end

include(joinpath(@__DIR__, "utils.jl"))
include(joinpath(@__DIR__, "interface.jl"))
include(joinpath(@__DIR__, "state.jl"))
include(joinpath(@__DIR__, "toy_examples.jl"))
include(joinpath(@__DIR__, "invariance_test.jl"))

end
