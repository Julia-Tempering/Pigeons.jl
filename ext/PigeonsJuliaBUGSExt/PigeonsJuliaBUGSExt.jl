module PigeonsJuliaBUGSExt

using Pigeons
if isdefined(Base, :get_extension)
    import JuliaBUGS
    using AbstractPPL # needed for AbstractPPL.get and parameter access
    using Bijectors # needed for transformations in getparams
    using DocStringExtensions
    using SplittableRandoms: SplittableRandom, split
    using Random
else
    import ..JuliaBUGS
    using ..AbstractPPL # needed for AbstractPPL.get and parameter access
    using ..Bijectors # needed for transformations in getparams
    using ..DocStringExtensions
    using ..SplittableRandoms: SplittableRandom, split
    using ..Random
end

include(joinpath(@__DIR__, "utils.jl"))
include(joinpath(@__DIR__, "interface.jl"))
include(joinpath(@__DIR__, "invariance_test.jl"))

end
