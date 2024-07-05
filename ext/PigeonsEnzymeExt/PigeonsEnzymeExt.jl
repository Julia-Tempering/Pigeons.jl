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

LogDensityProblemsAD.ADgradient(v::Val{:Enzyme}, log_potential, buffers::Pigeons.Augmentation) =
    Pigeons.BufferedAD(
        ADgradient(v, log_potential), # defaults to reverse mode, which makes more sense for log_potentials
        Pigeons.get_buffer(buffers, :enzyme_gradient_buffer, LogDensityProblems.dimension(log_potential)),
        nothing,
        nothing
    )

# this is dumb but it is the only way to disambiguate with the above
# TODO: find a smarter way? Maybe a generated function that iterates backends
function LogDensityProblemsAD.ADgradient(
    v::Val{:Enzyme},
    log_potential::Pigeons.InterpolatedLogPotential{<:Pigeons.InterpolatingPath{<:Any,<:Any,Pigeons.LinearInterpolator}},
    buffers::Pigeons.Augmentation
    )
    Pigeons.InterpolatedAD(
        log_potential,
        LogDensityProblemsAD.ADgradient(v, log_potential.path.ref, buffers), 
        LogDensityProblemsAD.ADgradient(v, log_potential.path.target, buffers), 
        Pigeons.get_buffer(buffers, :gradient_interpolated_buffer, LogDensityProblems.dimension(log_potential.path.ref))
    )
end

#=
logdensity and dimension already implemented in Pigeons (src/BufferedAD.jl)
only need logdensity_and_gradient
=#

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
