module PigeonsJuliaBUGSExt

using Pigeons
if isdefined(Base, :get_extension)
    import JuliaBUGS
    using AbstractPPL: getsym
    using Graphs
    using MetaGraphsNext
    using LogDensityProblems
    using DocStringExtensions
    using SplittableRandoms
    using Random
else
    import ..JuliaBUGS
    using ..AbstractPPL: getsym
    using ..Graphs
    using ..MetaGraphsNext
    using ..LogDensityProblems
    using ..DocStringExtensions
    using ..SplittableRandoms: SplittableRandom, split
    using ..Random
end

include(joinpath(@__DIR__, "interface.jl"))


end
