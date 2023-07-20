using Pigeons
using Statistics
using SplittableRandoms

# Create a custom type to control dispatch on the informal interface 'target'
struct MyLogPotential end

# In the following, we implement the methods described in the documentation at 
# https://julia-tempering.github.io/Pigeons.jl/dev/interfaces/#target (see "contract")

# Make it conform the 'log_potential' informal interface
# since we are using the default path, see 
# https://julia-tempering.github.io/Pigeons.jl/dev/reference/#Pigeons.create_path-Tuple{Any,%20Inputs}
(::MyLogPotential)(x) = -abs(x[1]) / 3

# Instruct to use a normal reference
Pigeons.default_reference(::MyLogPotential) = Pigeons.ScaledPrecisionNormalLogPotential(1.0, 1)

# Instruct how to create fresh state objects (using again MyLogPotential as a dummy type for dispatch on 
# the informal interface 'state_initializer')
Pigeons.create_state_initializer(my_potential::MyLogPotential, ::Inputs) = my_potential
Pigeons.initialization(::MyLogPotential, ::SplittableRandom, ::Int) = [0.0]

# Perform the sampling
pt = pigeons(target = MyLogPotential(), recorder_builders = Pigeons.online_recorder_builders())

# Example of how to compute mean and variance
@show mean(pt), var(pt)

nothing