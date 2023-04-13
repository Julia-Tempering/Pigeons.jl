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
        n_rounds = 3,
        n_chains = 5,
        recorder_builders = [Pigeons.online_recorder_builders(); Pigeons.interpolated_log_potentials]
    )

#@show Pigeons.global_barrier_is(pt)

points, cumulative = Pigeons.interpolated_log_potential_distribution(pt, 0.5, 0)


points2 = [1.0, 2.0, 3.0, 4.0]
cumulative2 = [0.3, 0.7, 0.8, 1.0]

# points = points2 
# cumulative = cumulative2

fct = Pigeons.interpolate_cdf(points, cumulative)

f = first(points)
l = last(points)

using Plots
#plot(fct, 0.0:0.1:5.0)
p1 = plot(fct, (f-5):0.1:(l+5))

inv = Pigeons.interpolate_cdf(points, cumulative, true)

p2 = plot(inv, 0.00001:0.00001:0.9999)

composition = inv ∘ fct 

p3 = plot(composition, (f-5):0.1:(l+5))

plot(p1, p2, p3)