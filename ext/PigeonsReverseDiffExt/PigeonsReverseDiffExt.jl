module PigeonsReverseDiffExt

using Pigeons
if isdefined(Base, :get_extension)
    using DocStringExtensions
    using ReverseDiff
    using LogDensityProblems
    using LogDensityProblemsAD
    import ReverseDiff: DiffResults
else
    using ..DocStringExtensions
    using ..ReverseDiff
    using ..LogDensityProblems
    using ..LogDensityProblemsAD
    import ..ReverseDiff: DiffResults
end

# TODO: currently, the concrete versions of ADGradientWrapper are defined only
# in the extensions of LogDensityProblemsAD. Therefore, it is impossible to 
# dispatch on them; see 
#   https://github.com/tpapp/LogDensityProblemsAD.jl/issues/32
# This is a HACK to extract that type 
const ReverseDiffLogDensity = if isdefined(Base, :get_extension)
    Base.get_extension(LogDensityProblemsAD, :LogDensityProblemsADReverseDiffExt).ReverseDiffLogDensity
else
    LogDensityProblemsAD.LogDensityProblemsADReverseDiffExt.ReverseDiffLogDensity
end

# adapted from LogDensityProblemsAD to use the Replica's buffer
function LogDensityProblems.logdensity_and_gradient(
    b::Pigeons.BufferedAD{<:ReverseDiffLogDensity},
    x::AbstractVector
    )
    ℓ = b.enclosed.ℓ
    buffer = b.buffer
    diff_result = DiffResults.MutableDiffResult(zero(eltype(buffer)), (buffer, ))
    ReverseDiff.gradient!(diff_result, Base.Fix1(LogDensityProblems.logdensity, ℓ), x)

    return (DiffResults.value(diff_result), DiffResults.gradient(diff_result))
end

end # End module
