
using Pkg 
Pkg.activate(".")
using Revise
using Pigeons 
using Statistics

target_rate = 2.0

pt = pigeons(
        target = Pigeons.ExpDist(target_rate), #Product(Normal.(zeros(gauss_dim), 2 * ones(gauss_dim))), 
        n_rounds = 10,
        n_chains = 2,
        fused_swaps = true,
        recorder_builders = [Pigeons.online_recorder_builders(); Pigeons.interpolated_log_potentials]
    )

@show mean(pt), var(pt)

beta = 1.0
points, cumulative = Pigeons.interpolated_log_potential_distribution(pt, beta, 0)

@show maximum(points)

fct = Pigeons.interpolate_cdf(points, cumulative)

f = first(points)
l = last(points)

using Plots

range = 0.0001:0.0001:0.9999 
range2 = (f-5):0.1:(l+5)

p1 = plot(fct, range2)

inv = Pigeons.interpolate_cdf(points, cumulative, true)


p2 = plot(inv, range)

composition = inv ∘ fct 

p3 = plot(composition, range2)

I(b) = b ? 1.0 : 0.0

analytic_rate = (1-beta) * 1 + beta * target_rate
analytic_F(x) = exp(x - log(analytic_rate)) * I(x ≤ log(analytic_rate)) + I(x > log(analytic_rate))

p4 = plot(analytic_F, range2)

plot(p1, p2, p3, p4)