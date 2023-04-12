using Pigeons
using Distributions
using Statistics
using SplittableRandoms
using Random
using QuadGK

dim = 1

Pigeons.create_explorer(::Distribution, ::Inputs) = Pigeons.SliceSampler() 

Pigeons.create_reference_log_potential(::Distribution, ::Inputs) = Product(Normal.(zeros(dim), ones(dim)))

Pigeons.sample_iid!(distribution::Distribution, replica) = 
    rand!(replica.rng, distribution, replica.state)

Pigeons.create_state_initializer(my_potential::Distribution, ::Inputs) = my_potential
Pigeons.initialization(distribution::Distribution, ::SplittableRandom, ::Int) = zeros(length(distribution))

pt = pigeons(
        target = Product(Normal.(zeros(dim), 10 * ones(dim))), 
        n_rounds = 15,
        recorder_builders = [Pigeons.online_recorder_builders(); Pigeons.interpolated_log_potentials]
    )

# Steps to build height transports...

# given beta, find closest grids 


is = Pigeons.interpolated_log_potential_distribution(pt, 0.1)

# use formula from notes to check it agrees with standard lambda estimate..
barriers = Pigeons.communication_barriers(pt.reduced_recorders, pt.shared.tempering.schedule)

# TODO: currently broken
@show quadgk(x -> barriers.localbarrier(x), 0.0, 1.0)
@show quadgk(x -> Pigeons.local_barrier_is(pt, x), 0.0, 1.0)

@show pt.shared.tempering.schedule

grid_point = 0.4109797329109476
grid_index = 2
@show barriers.localbarrier(grid_point)
@show Pigeons.local_barrier_is(pt, grid_point)




# Next: check formula 0.5 E|V-V'| = int F (1 - F) - it has to be right...

# build IS, sort, cumsum

# create CDF and inverse CDF objects (interpolate, extrapolate)

nothing