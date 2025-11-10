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

# Ensure JuliaBUGSPath models never carry generated log-density functions, which
# are not serializable across MPI workers. If a model was compiled with source
# generation enabled, recompile it with `skip_source_generation=true` and retain
# the original transformation flag.
function Pigeons.JuliaBUGSPath(model::JuliaBUGS.BUGSModel)
    mpi_safe_model = isnothing(model.log_density_computation_function) ? model :
        let recomp = JuliaBUGS.compile(
                model.model_def,
                model.data,
                model.evaluation_env;
                skip_source_generation=true
            )
            JuliaBUGS.settrans(recomp, model.transformed)
        end
    T = Pigeons.JuliaBUGSPath
    return Base.@invoke T(mpi_safe_model::Any)
end

end
