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

# special ADgradient constructor for ReverseDiff
function LogDensityProblemsAD.ADgradient(
    kind::Val{:ReverseDiff}, 
    log_potential,
    buffers::Pigeons.Augmentation
    )
    d = LogDensityProblems.dimension(log_potential)
    buffer = Pigeons.get_buffer(buffers, :gradient_buffer, d)
    compile_tape = Pigeons.get_tape_compilation_strategy()
    enclosed = ADgradient(kind, log_potential; x = buffer, compile=Val{compile_tape}())
    diff_result = DiffResults.MutableDiffResult(zero(eltype(buffer)), (buffer, ))
    Pigeons.BufferedAD(enclosed, diff_result, nothing, nothing)
end

# adapted from LogDensityProblemsAD to use the Replica's buffer
function LogDensityProblems.logdensity_and_gradient(
    b::Pigeons.BufferedAD{<:ReverseDiffLogDensity},
    x::AbstractVector
    )
    diff_result = b.buffer
    compiled_tape = b.enclosed.compiledtape
    if compiled_tape === nothing
        ReverseDiff.gradient!(diff_result, Base.Fix1(LogDensityProblems.logdensity, b.enclosed.ℓ), x)
    else
        ReverseDiff.gradient!(diff_result, compiled_tape, x)
    end
    return (DiffResults.value(diff_result), DiffResults.gradient(diff_result))
end

end # End module
