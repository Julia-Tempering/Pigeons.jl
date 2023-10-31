module PigeonsBridgeStanExt

using Pigeons
if isdefined(Base, :get_extension)
    using BridgeStan
    using LogDensityProblems
    using Serialization
    using LogDensityProblemsAD
    using DocStringExtensions
    using SplittableRandoms
    using Random
else
    using ..BridgeStan
    using ..LogDensityProblems
    using ..Serialization
    using ..LogDensityProblemsAD
    using ..DocStringExtensions
    using ..SplittableRandoms: SplittableRandom, split
    using ..Random
end

import Pigeons: StanLogPotential



include(joinpath(@__DIR__, "interface.jl"))
include(joinpath(@__DIR__, "state.jl"))
include(joinpath(@__DIR__, "toy_examples.jl"))

end
