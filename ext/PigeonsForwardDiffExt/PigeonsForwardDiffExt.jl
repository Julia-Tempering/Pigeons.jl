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
const ForwardDiffLogDensity = Base.get_extension(LogDensityProblemsAD, :LogDensityProblemsADForwardDiffExt).ForwardDiffLogDensity

# adapted from LogDensityProblemsAD to use the Replica's buffer
function LogDensityProblems.logdensity_and_gradient(
    b::Pigeons.BufferedAD{<:ForwardDiffLogDensity},
    x::AbstractVector
    )
    ℓ = b.enclosed.ℓ
    chunk = b.enclosed.chunk
    tag = b.enclosed.tag
    gradient_config = b.enclosed.gradient_config
    buffer = b.buffer

    diff_result = DiffResults.MutableDiffResult(zero(eltype(buffer)), (buffer, ))
    ℓ_fix = Base.Fix1(logdensity, ℓ)

    if gradient_config ≡ nothing
        gradient_config = _make_gradient_config(ℓ_fix, x, chunk, tag)
    end

    ForwardDiff.gradient!(diff_result, ℓ_fix, x, gradient_config)
    
    return (DiffResults.value(diff_result), DiffResults.gradient(diff_result))
end

end # End module
