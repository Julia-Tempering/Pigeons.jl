module PigeonsEnzymeExt

using Pigeons
if isdefined(Base, :get_extension)
    using DocStringExtensions
    using Enzyme
    using LogDensityProblems
    using LogDensityProblemsAD
else
    using ..DocStringExtensions
    using ..Enzyme
    using ..LogDensityProblems
    using ..LogDensityProblemsAD
end

# A simpler version of the wrapper defined in LogDensityProblemsAD's extension
struct EnzymeWrapper{TLP} <: Pigeons.ADWrapper
    log_potential::TLP
end

# special ADgradient constructor for Enzyme
function LogDensityProblemsAD.ADgradient(
    kind::Val{:Enzyme}, 
    log_potential, 
    buffers::Pigeons.Augmentation
    )
    d = LogDensityProblems.dimension(log_potential)
    buffer = Pigeons.get_buffer(buffers, :gradient_buffer, d)
    enclosed = EnzymeWrapper(log_potential)
    Pigeons.BufferedAD(enclosed, buffer, nothing, nothing)
end

# adapted from LogDensityProblemsAD to use the Replica's buffer
function LogDensityProblems.logdensity_and_gradient(
    b::Pigeons.BufferedAD{<:EnzymeWrapper},
    x::AbstractVector
    )
    ∂ℓ_∂x = fill!(b.buffer, zero(eltype(b.buffer))) # NB: Enzyme gives erroneous answer if buffer is not zeroed first
    _, y = Enzyme.autodiff(
        Enzyme.ReverseWithPrimal, LogDensityProblems.logdensity, Enzyme.Active,
        Enzyme.Const(b.enclosed.log_potential), Enzyme.Duplicated(x, ∂ℓ_∂x)
    )
    y, ∂ℓ_∂x
end

end # End module
