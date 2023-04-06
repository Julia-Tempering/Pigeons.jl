using Pigeons
using Statistics
using SplittableRandoms

# Create a custom type to control dispatch on the informal interface 'target'
struct MyLogPotential end

# Make it conform the 'log_potential' informal interface
(::MyLogPotential)(x) = -abs(x[1]) / 3

# Instruct to use the slice sampler for MyLogPotential
Pigeons.create_explorer(::MyLogPotential, ::Inputs) = Pigeons.SliceSampler() 

# Instruct to use a normal reference
Pigeons.create_reference_log_potential(::MyLogPotential, ::Inputs) = Pigeons.ScaledPrecisionNormalLogPotential(1.0, 1)

# Instruct how to create fresh state objects (using again MyLogPotential as a dummy )
Pigeons.create_state_initializer(my_potential::MyLogPotential, ::Inputs) = my_potential
Pigeons.initialization(::MyLogPotential, ::SplittableRandom, ::Int) = [0.0]

# Perform the sampling
pt = pigeons(target = MyLogPotential(), recorder_builders = Pigeons.online_recorder_builders())

# Example of how to compute mean and variance
@show mean(pt), var(pt)

nothing