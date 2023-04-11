using Pigeons
using Statistics
using SplittableRandoms
using LogExpFunctions

#=
More involved version of general-target, where we use a 
non-standard path of distribution and reference.
=#

# Create a custom type to control dispatch on the informal interface 'target'
struct AnotherLogPotential end

# In the following, we implement the methods described in the documentation at 
# https://julia-tempering.github.io/Pigeons.jl/dev/interfaces/#target (see "contract")

# Make it conform the 'log_potential' informal interface
# since we are using the default path, see 
# https://julia-tempering.github.io/Pigeons.jl/dev/reference/#Pigeons.create_path-Tuple{Any,%20Inputs}
(::AnotherLogPotential)(x) = -abs(x[1]) / 3

# Instruct to use the slice sampler for MyLogPotential
Pigeons.create_explorer(::AnotherLogPotential, ::Inputs) = Pigeons.SliceSampler() 

#= Example of a non-standard path of distribution.
There are two ways to do so:
- most general is to use the 'path' informal interface (see e.g. ScaledPrecisionNormalPath for an example)
- here we illustrate the use of InterpolatingPath based on a non-standard interpolator
=#
struct MixInterpolator end

# Here we show an example where the interpolation is done using log[ (1-beta) pi_0 + beta pi ]
Pigeons.interpolate(interpolator::MixInterpolator, ref_log_potential, target_log_potential, beta, x) = 
    if beta == 0.0
        ref_log_potential(x)
    elseif beta == 1.0 
        target_log_potential(x) 
    else
        logaddexp(
            log(1-beta) + ref_log_potential(x), 
            log(beta) + target_log_potential(x))
    end

# Instruct to use the non-standard path we just created
Pigeons.create_path(target::AnotherLogPotential, inputs::Inputs) = Pigeons.InterpolatingPath(
    Pigeons.create_reference_log_potential(target, inputs),
    target, 
    MixInterpolator())

Pigeons.create_reference_log_potential(::AnotherLogPotential, ::Inputs) = Pigeons.ScaledPrecisionNormalLogPotential(1.0, 1)

# Instruct how to create fresh state objects (using again MyLogPotential as a dummy type for dispatch on 
# the informal interface 'state_initializer')
Pigeons.create_state_initializer(my_potential::AnotherLogPotential, ::Inputs) = my_potential
Pigeons.initialization(::AnotherLogPotential, ::SplittableRandom, ::Int) = [0.0]

# Perform the sampling
pt = pigeons(target = AnotherLogPotential(), recorder_builders = Pigeons.online_recorder_builders())

# Example of how to compute mean and variance
@show mean(pt), var(pt)

nothing