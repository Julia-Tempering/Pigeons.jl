# Utilities to cast problems into the LogDensityProblems.jl interface

# function LogDensityProblemsAD.ADgradient(backend, inter::InterpolatedLogPotential{InterpolatingPath{R, T, LinearInterpolator}, B}, x) where {R, T, B}


# ####

# const autodiff_backend = Ref(:ForwardDiff)

# # If gradient!! not specified, ignore the buffer and use gradient()
# gradient!!(log_potential, x, buffer) = gradient(log_potential, x)

# gradient(log_potential, vi::DynamicPPL.TypedVarInfo) = 
#     gradient(log_potential, DynamicPPL.getall(vi))

# function logdensity_and_gradient(log_potential::TuringLogPotential, current_point::AbstractVector)
#     context = log_potential.only_prior ? DynamicPPL.PriorContext() : DynamicPPL.DefaultContext()
#     # The LogDensityFunction actually contains state info, so we don't want 
#     # to use them as log_potential's, moreover, 
#     # LogDensityFunction() and ADgradient() seems cheaper than logdensity_and_gradient 
#     # so we are should not be losing more than a factor 2 speed here by 
#     # repeatedly extracting the LogDensityFunction and its ADgradient
#     fct = DynamicPPL.LogDensityFunction(vi, log_potential.model, context)
#     gradient_calculator = ADgradient(autodiff_backend[], fct)
#     return LogDensityProblemsAD.logdensity_and_gradient(gradient_calculator, current_point)
# end

# gradient(log_potential::TuringLogPotential, current_point::AbstractVector) =
#     last(logdensity_and_gradient(log_potential, current_point))

# (log_potential::TuringLogPotential)(state::AbstractVector) = first(logdensity_and_gradient(log_potential, state))

# function gradient(log_potential, x) 
#     @assert autodiff_backend[] == :ForwardDiff
#     ForwardDiff.gradient(log_potential, x)
# end

# gradient(inter::InterpolatedLogPotential{InterpolatingPath{R, T, LinearInterpolator}, B}, x) where {R, T, B} =
#     interpolate(
#         inter.path.interpolator, 
#         gradient(inter.path.ref, x),
#         gradient(inter.path.target, x),
#         inter.beta
#     )
