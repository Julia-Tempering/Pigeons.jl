using Pigeons
using Distributions
using Statistics
using SplittableRandoms
using Random
using QuadGK

dim = 5

Pigeons.create_explorer(::Distribution, ::Inputs) = Pigeons.SliceSampler() 

Pigeons.create_reference_log_potential(::Distribution, ::Inputs) = Product(Normal.(zeros(dim), ones(dim)))

Pigeons.sample_iid!(distribution::Distribution, replica) = 
    rand!(replica.rng, distribution, replica.state)

Pigeons.create_state_initializer(my_potential::Distribution, ::Inputs) = my_potential
Pigeons.initialization(distribution::Distribution, ::SplittableRandom, ::Int) = zeros(length(distribution))

# true value for Λ seems around 3.9 based on a large run

pt = pigeons(
        target = Product(Normal.(zeros(dim), 10 * ones(dim))), 
        n_rounds = 15,
        n_chains = 5,
        recorder_builders = [Pigeons.online_recorder_builders(); Pigeons.interpolated_log_potentials]
    )

@show Pigeons.global_barrier_is(pt)



# @show pt.shared.tempering.schedule

# grid_point = 0.4109797329109476
# grid_index = 2
# @show barriers.localbarrier(grid_point)
# @show Pigeons.local_barrier_is(pt, grid_point)




# Next: check formula 0.5 E|V-V'| = int F (1 - F) - it has to be right...

# build IS, sort, cumsum

# create CDF and inverse CDF objects (interpolate, extrapolate)

nothing