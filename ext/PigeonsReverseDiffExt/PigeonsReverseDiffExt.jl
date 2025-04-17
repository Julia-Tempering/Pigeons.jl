module PigeonsReverseDiffExt

using Pigeons
if isdefined(Base, :get_extension)
    using ADTypes
    using DocStringExtensions
    using ReverseDiff
    using LogDensityProblems
    using LogDensityProblemsAD
    import ReverseDiff: DiffResults
else
    using ..ADTypes
    using ..DocStringExtensions
    using ..ReverseDiff
    using ..LogDensityProblems
    using ..LogDensityProblemsAD
    import ..ReverseDiff: DiffResults
end

# A simpler version of the wrapper defined in LogDensityProblemsAD's extension
struct ReverseDiffWrapper{TLP, TCT} <: Pigeons.ADWrapper
    log_potential::TLP
    compiled_tape::TCT
end
function make_compiled_tape(log_potential, x)
    lp_fix = Base.Fix1(LogDensityProblems.logdensity, log_potential)
    tape = ReverseDiff.GradientTape(lp_fix, x)
    return ReverseDiff.compile(tape)
end
compute_gradient!(rdw::ReverseDiffWrapper, diff_result, x) =
    ReverseDiff.gradient!(
        diff_result, 
        Base.Fix1(LogDensityProblems.logdensity, rdw.log_potential), x
    )
compute_gradient!(rdw::ReverseDiffWrapper{<:Any,<:ReverseDiff.CompiledTape}, diff_result, x) =
    ReverseDiff.gradient!(diff_result, rdw.compiled_tape, x)

# special ADgradient constructor for ReverseDiff
function LogDensityProblemsAD.ADgradient(
    kind::ADTypes.AutoReverseDiff, 
    log_potential,
    buffers::Pigeons.Augmentation
    )
    d = LogDensityProblems.dimension(log_potential)
    buffer = Pigeons.get_buffer(buffers, :gradient_buffer, d)
    should_compile = kind isa ADTypes.AutoReverseDiff{true}
    if should_compile
        @info """

        Using ReverseDiff with tape compilation, which usually results in huge performance gains.
        However, if your model does branching on latent variables, you will get inconsistent results.
        """ maxlog=1
    else
        @info """

        Using ReverseDiff without tape compilation. If your model does not branch on latent variables,
        you may be able to obtain a huge performance gain by enabling tape compilation. You can do this
        by passing `default_autodiff_backend=AutoReverseDiff(compile=true)` to your gradient-based explorer.            
        """ maxlog=1
    end
    compiled_tape = should_compile ? make_compiled_tape(log_potential, buffer) : nothing
    enclosed = ReverseDiffWrapper(log_potential, compiled_tape)
    diff_result = DiffResults.MutableDiffResult(zero(eltype(buffer)), (buffer, ))
    Pigeons.BufferedAD(enclosed, diff_result, nothing, nothing)
end

# adapted from LogDensityProblemsAD to use the Replica's buffer
function LogDensityProblems.logdensity_and_gradient(
    b::Pigeons.BufferedAD{<:ReverseDiffWrapper},
    x::AbstractVector
    )
    diff_result = b.buffer
    compute_gradient!(b.enclosed, diff_result, x)
    return (DiffResults.value(diff_result), DiffResults.gradient(diff_result))
end

end # End module
