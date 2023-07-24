using Pigeons
using Statistics
using Random
using LogExpFunctions

#=
More involved version of general-target, where we use a 
non-standard path of distribution and reference.
=#

# start off the same as general-target..
struct AnotherLogPotential end
(::AnotherLogPotential)(x) = -abs(x[1]) / 3

#= Example of a non-standard path of distribution.
There are two ways to do so:
- most general is to use the 'path' informal interface (see e.g. ScaledPrecisionNormalPath for an example)
- here we illustrate the use of InterpolatingPath based on a non-standard interpolator
=#
struct MixInterpolator end

# Here we show an example where the interpolation is done using log[ (1-beta) pi_0 + beta pi ]
Pigeons.interpolate(interpolator::MixInterpolator, ref_log_potential, target_log_potential, beta) = 
    logaddexp(
        log(1-beta) + ref_log_potential, 
        log(beta) + target_log_potential)


# Instruct to use the non-standard path we just created
Pigeons.create_path(target::AnotherLogPotential, inputs::Inputs) = Pigeons.InterpolatingPath(
    Pigeons.create_reference_log_potential(inputs),
    target, 
    MixInterpolator())

# rest is the same as general-target
Pigeons.default_reference(::AnotherLogPotential) = Pigeons.ScaledPrecisionNormalLogPotential(1.0, 1)
Pigeons.initialization(::AnotherLogPotential, ::AbstractRNG, ::Int) = [0.0]

# Perform the sampling
pt = pigeons(target = AnotherLogPotential(), record = record_online())

# Example of how to compute mean and variance
@show mean(pt), var(pt)

nothing