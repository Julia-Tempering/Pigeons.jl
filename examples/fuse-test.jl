using Pigeons
using Distributions
using Statistics
using SplittableRandoms
using Random
using QuadGK

dim = 1

Pigeons.create_explorer(distribution::Distribution, ::Inputs) = Pigeons.SliceSampler(n_passes = 4)

Pigeons.explorer_recorder_builders(::Distribution) = []
Pigeons.adapt_explorer(::Distribution, _, _) = nothing

Pigeons.create_reference_log_potential(::Distribution, ::Inputs) = Product(Normal.(zeros(dim), ones(dim)))

Pigeons.sample_iid!(distribution::Distribution, replica) = 
    rand!(replica.rng, distribution, replica.state)

Pigeons.create_state_initializer(my_potential::Distribution, ::Inputs) = my_potential
Pigeons.initialization(distribution::Distribution, ::SplittableRandom, ::Int) = zeros(length(distribution))


# true value for Λ seems around 3.9 based on a large run

pt = pigeons(
        target = Product(Normal.(zeros(dim), 2 * ones(dim))), 
        n_rounds = 10,
        n_chains = 10,
        fused_swaps = true,
        recorder_builders = [Pigeons.online_recorder_builders(); Pigeons.interpolated_log_potentials]
    )

@show mean(pt), var(pt)

points, cumulative = Pigeons.interpolated_log_potential_distribution(pt, 0.5, 0)


fct = Pigeons.interpolate_cdf(points, cumulative)

f = first(points)
l = last(points)

using Plots

p1 = plot(fct, (f-5):0.1:(l+5))

inv = Pigeons.interpolate_cdf(points, cumulative, true)

range = 0.001:0.001:0.999
p2 = plot(inv, range)

composition = inv ∘ fct 

p3 = plot(composition, (f-5):0.1:(l+5))

plot(p1, p2, p3)