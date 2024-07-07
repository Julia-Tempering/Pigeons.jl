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

# adapted from LogDensityProblemsAD to use the Replica's buffer
# TODO: currently, the concrete versions of ADGradientWrapper are defined only
# in the extensions of LogDensityProblemsAD. Therefore, it is impossible to 
# dispatch on them; see 
#   https://github.com/tpapp/LogDensityProblemsAD.jl/issues/32
# Since this (Enzyme) is our only extension using the ADGradientWrapper interface
# it is ok to use this abstract type to dispatch. But problems will arise the minute
# we want to implement another backend. So keep an eye on the above issue.
function LogDensityProblems.logdensity_and_gradient(
    b::Pigeons.BufferedAD{<:LogDensityProblemsAD.ADGradientWrapper}, # assuming Enzyme (FIXME)
    x::AbstractVector
    )
    ℓ = b.enclosed.ℓ
    ∂ℓ_∂x = b.buffer
    _, y = Enzyme.autodiff(
        Enzyme.ReverseWithPrimal, LogDensityProblems.logdensity, Enzyme.Active,
        Enzyme.Const(ℓ), Enzyme.Duplicated(x, ∂ℓ_∂x)
    )
    y, ∂ℓ_∂x
end

end # End module
