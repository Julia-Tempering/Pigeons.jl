module PigeonsDynamicPPLExt

using Pigeons
if isdefined(Base, :get_extension)
    import DynamicPPL
    using Distributions
    using LogDensityProblems
    using LogDensityProblemsAD
    using DocStringExtensions
    using Random
else
    import ..DynamicPPL
    using ..Distributions
    using ..LogDensityProblems
    using ..LogDensityProblemsAD
    using ..DocStringExtensions
    using ..Random
end


include(joinpath(@__DIR__, "interface.jl"))
include(joinpath(@__DIR__, "state.jl"))
include(joinpath(@__DIR__, "toy_examples.jl"))

end
