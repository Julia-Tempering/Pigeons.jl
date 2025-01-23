module PigeonsForwardDiffExt

using Pigeons
if isdefined(Base, :get_extension)
    using DocStringExtensions
    using ForwardDiff
    using LogDensityProblems
    using LogDensityProblemsAD
    import ForwardDiff: DiffResults
else
    using ..DocStringExtensions
    using ..ForwardDiff
    using ..LogDensityProblems
    using ..LogDensityProblemsAD
    import ..ForwardDiff: DiffResults
end

# A simpler version of the wrapper defined in LogDensityProblemsAD's extension
struct ForwardDiffWrapper{TLP, TGC <: ForwardDiff.GradientConfig} <: Pigeons.ADWrapper
    log_potential::TLP
    gradient_config::TGC
end

# special ADgradient constructor for ForwardDiff
function LogDensityProblemsAD.ADgradient(
    kind::Val{:ForwardDiff}, 
    log_potential, 
    buffers::Pigeons.Augmentation
    )
    d = LogDensityProblems.dimension(log_potential)
    buffer = Pigeons.get_buffer(buffers, :gradient_buffer, d)
    lp_fix = Base.Fix1(LogDensityProblems.logdensity, log_potential)
    gradient_config = ForwardDiff.GradientConfig(lp_fix, buffer, ForwardDiff.Chunk(d))
    enclosed = ForwardDiffWrapper(log_potential, gradient_config)
    diff_result = DiffResults.MutableDiffResult(zero(eltype(buffer)), (buffer, ))
    Pigeons.BufferedAD(enclosed, diff_result, nothing, nothing)
end

# adapted from LogDensityProblemsAD to use the Replica's buffer
function LogDensityProblems.logdensity_and_gradient(
    b::Pigeons.BufferedAD{<:ForwardDiffWrapper},
    x::AbstractVector
    )
    diff_result = b.buffer
    lp_fix = Base.Fix1(LogDensityProblems.logdensity, b.enclosed.log_potential)
    ForwardDiff.gradient!(diff_result, lp_fix, x, b.enclosed.gradient_config)
    return (DiffResults.value(diff_result), DiffResults.gradient(diff_result))
end

end # End module
