module PigeonsJuliaBUGSExt

using Pigeons
if isdefined(Base, :get_extension)
    import JuliaBUGS
    using AbstractPPL # needed for AbstractPPL.get and parameter access
    using Bijectors # needed for transformations in getparams
    using DocStringExtensions
    using SplittableRandoms: SplittableRandom, split
    using Random
    import Serialization
else
    import ..JuliaBUGS
    using ..AbstractPPL # needed for AbstractPPL.get and parameter access
    using ..Bijectors # needed for transformations in getparams
    using ..DocStringExtensions
    using ..SplittableRandoms: SplittableRandom, split
    using ..Random
    import ..Serialization
end

include(joinpath(@__DIR__, "utils.jl"))
include(joinpath(@__DIR__, "interface.jl"))
include(joinpath(@__DIR__, "invariance_test.jl"))

# Provide a no-op explorer as default for JuliaBUGS targets when no explorer
# is explicitly requested by the user/tests. Other tests explicitly pass an
# explorer (e.g., SliceSampler), so this only affects ad-hoc runs.
struct NoOpExplorer end
Pigeons.step!(::NoOpExplorer, replica, shared) = nothing
Pigeons.explorer_recorder_builders(::NoOpExplorer) = []
Pigeons.default_explorer(::Pigeons.JuliaBUGSPath) = NoOpExplorer()

end
