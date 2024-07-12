module PigeonsDynamicPPLExt

using Pigeons
if isdefined(Base, :get_extension)
    import DynamicPPL
    using Distributions
    using FillArrays: Zeros
    using LinearAlgebra: I
    using LogDensityProblems
    using LogDensityProblemsAD
    using DocStringExtensions
    using SplittableRandoms
    using Random
else
    import ..DynamicPPL
    using ..Distributions
    using ..FillArrays: Zeros
    using ..LinearAlgebra: I
    using ..LogDensityProblems
    using ..LogDensityProblemsAD
    using ..DocStringExtensions
    using ..SplittableRandoms: SplittableRandom, split
    using ..Random
end

include(joinpath(@__DIR__, "utils.jl"))
include(joinpath(@__DIR__, "interface.jl"))
include(joinpath(@__DIR__, "state.jl"))
include(joinpath(@__DIR__, "toy_examples.jl"))
include(joinpath(@__DIR__, "invariance_test.jl"))

end
