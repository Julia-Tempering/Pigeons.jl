module PigeonsJuliaBUGSExt

using Pigeons
if isdefined(Base, :get_extension)
    import JuliaBUGS
    using LogDensityProblems
    using DocStringExtensions
    using SplittableRandoms: SplittableRandom, split
    using Random
else
    import ..JuliaBUGS
    using ..LogDensityProblems
    using ..DocStringExtensions
    using ..SplittableRandoms: SplittableRandom, split
    using ..Random
end

include(joinpath(@__DIR__, "interface.jl"))
include(joinpath(@__DIR__, "invariance_test.jl"))

end
