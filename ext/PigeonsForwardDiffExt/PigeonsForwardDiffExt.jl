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

# TODO: currently, the concrete versions of ADGradientWrapper are defined only
# in the extensions of LogDensityProblemsAD. Therefore, it is impossible to 
# dispatch on them; see 
#   https://github.com/tpapp/LogDensityProblemsAD.jl/issues/32
# This is a HACK to extract that type 
const ForwardDiffLogDensity = if isdefined(Base, :get_extension)
    Base.get_extension(LogDensityProblemsAD, :LogDensityProblemsADForwardDiffExt).ForwardDiffLogDensity
else
    LogDensityProblemsAD.LogDensityProblemsADForwardDiffExt.ForwardDiffLogDensity
end

# special ADgradient constructor for ForwardDiff
function LogDensityProblemsAD.ADgradient(
    kind::Val{:ForwardDiff}, 
    log_potential, 
    buffers::Pigeons.Augmentation
    )
    d = LogDensityProblems.dimension(log_potential)
    buffer = Pigeons.get_buffer(buffers, :gradient_buffer, d) 
    enclosed = ADgradient(kind, log_potential; x = buffer)
    diff_result = DiffResults.MutableDiffResult(zero(eltype(buffer)), (buffer, ))
    Pigeons.BufferedAD(enclosed, diff_result, nothing, nothing)
end

# adapted from LogDensityProblemsAD to use the Replica's buffer
function LogDensityProblems.logdensity_and_gradient(
    b::Pigeons.BufferedAD{<:ForwardDiffLogDensity},
    x::AbstractVector
    )
    diff_result = b.buffer
    ℓ_fix = Base.Fix1(LogDensityProblems.logdensity, b.enclosed.ℓ)
    ForwardDiff.gradient!(diff_result, ℓ_fix, x, b.enclosed.gradient_config)

    return (DiffResults.value(diff_result), DiffResults.gradient(diff_result))
end

end # End module
