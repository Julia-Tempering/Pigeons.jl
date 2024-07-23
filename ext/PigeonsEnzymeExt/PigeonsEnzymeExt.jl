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

# TODO: currently, the concrete versions of ADGradientWrapper are defined only
# in the extensions of LogDensityProblemsAD. Therefore, it is impossible to 
# dispatch on them; see 
#   https://github.com/tpapp/LogDensityProblemsAD.jl/issues/32
# This is a HACK to extract that type 
const EnzymeGradientLogDensity = if isdefined(Base, :get_extension)
    Base.get_extension(LogDensityProblemsAD, :LogDensityProblemsADEnzymeExt).EnzymeGradientLogDensity
else
    LogDensityProblemsAD.LogDensityProblemsADEnzymeExt.EnzymeGradientLogDensity
end

# adapted from LogDensityProblemsAD to use the Replica's buffer
function LogDensityProblems.logdensity_and_gradient(
    b::Pigeons.BufferedAD{<:EnzymeGradientLogDensity},
    x::AbstractVector
    )
    ∂ℓ_∂x = fill!(b.buffer, zero(eltype(b.buffer))) # NB: Enzyme gives erroneous answer if buffer is not zeroed first
    _, y = Enzyme.autodiff(
        Enzyme.ReverseWithPrimal, LogDensityProblems.logdensity, Enzyme.Active,
        Enzyme.Const(b.enclosed.ℓ), Enzyme.Duplicated(x, ∂ℓ_∂x)
    )
    y, ∂ℓ_∂x
end

end # End module
