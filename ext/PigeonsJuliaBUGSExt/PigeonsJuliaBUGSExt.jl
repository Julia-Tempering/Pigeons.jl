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

# Custom constructor that ensures MPI-safe models
# This recompiles the model without source generation to ensure consistent type parameters
function Pigeons.JuliaBUGSPath(model::JuliaBUGS.BUGSModel)
    # Check if model has generated function (non-Nothing type parameter)
    if !isnothing(model.log_density_computation_function)
        # Recompile without source generation to get consistent type: BUGSModel{..., Nothing}
        # This ensures serialization works across MPI processes
        mpi_safe_model = JuliaBUGS.compile(
            model.model_def,
            model.data,
            model.evaluation_env;
            skip_source_generation=true
        )
        # Restore the transformation state
        mpi_safe_model = JuliaBUGS.settrans(mpi_safe_model, model.transformed)
    else
        # Model already has Nothing type, safe to use directly
        mpi_safe_model = model
    end

    # Call the default constructor with MPI-safe model
    T = Pigeons.JuliaBUGSPath
    return Base.@invoke T(mpi_safe_model::Any)
end

end
