using Pigeons
using Distributions
using Statistics
using SplittableRandoms
using Random

dim = 10

Pigeons.create_explorer(::Distribution, ::Inputs) = Pigeons.SliceSampler() 

Pigeons.create_reference_log_potential(::Distribution, ::Inputs) = Product(Normal.(zeros(dim), ones(dim)))

Pigeons.sample_iid!(distribution::Distribution, replica) = 
    rand!(replica.rng, distribution, replica.state)

Pigeons.create_state_initializer(my_potential::Distribution, ::Inputs) = my_potential
Pigeons.initialization(distribution::Distribution, ::SplittableRandom, ::Int) = zeros(length(distribution))

pt = pigeons(target = Product(Normal.(zeros(dim), 10 * ones(dim))), recorder_builders = [Pigeons.online_recorder_builders(); Pigeons.interpolated_log_potentials])

# Steps to build height transports...

# given beta, find closest grids 


is = Pigeons.interpolated_log_potential_distribution(pt, 0.1)

# build IS, sort, cumsum

# create CDF and inverse CDF objects (interpolate, extrapolate)

nothing