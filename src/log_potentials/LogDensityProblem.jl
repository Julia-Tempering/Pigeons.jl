"""
Flag that this satisfies the LogDensityProblem interface. 
Note: our log_potentials interface is more general, as 
it applies beyond R^n. 
"""
@concrete struct LogDensityProblem
    density 
end 



# Make LogDensityProblem satisfy our log_potential
(ldp::LogDensityProblem)(x) = LogDensityProblems.logdensity(ldp.density, x)

# Facilitate getting gradients out 
LogDensityProblems.logdensity_and_gradient(interpolated::InterpolatedLogPotential, x) = 
    interpolate(
        interpolated.path.interpolator, 
        logdensity_and_gradient(interpolated.path.ref.density, x), 
        logdensity_and_gradient(interpolated.path.target.density, x), 
        interpolated.beta
    )


    