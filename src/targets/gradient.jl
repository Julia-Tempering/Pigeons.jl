function gradient(log_potential::TuringLogPotential, vi, autodiff_backend = :ForwardDiff)
    current_point = DynamicPPL.getall(vi) # NB: this will also get the discrete params (are the gradients always set to zero for them?)
    context = log_potential.only_prior ? DynamicPPL.PriorContext() : DynamicPPL.DefaultContext()
    # The LogDensityFunction actually contains state info, so we don't want 
    # to use them as log_potential's, moreover, 
    # LogDensityFunction() and ADgradient() seems cheaper than logdensity_and_gradient 
    # so we are should not be losing more than a factor 2 speed here 
    fct = DynamicPPL.LogDensityFunction(vi, log_potential.model, context)
    gradient_calculator = ADgradient(autodiff_backend, fct)
    _, grad = LogDensityProblemsAD.logdensity_and_gradient(gradient_calculator, current_point)
    return grad
end

function gradient(interpolated::InterpolatedLogPotential{InterpolatingPath{R, T, LinearInterpolator}, B}, x, autodiff_backend = :ForwardDiff) where {R, T, B}
    @assert 0.0 ≤ beta ≤ 1.0 
    return  @weighted(1.0 - beta, gradient(interpolated.path.ref.density, x, autodiff_backend)) +
            @weighted(beta,       gradient(interpolated.path.target.density, x, autodiff_backend))
end
