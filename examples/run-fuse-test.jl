
using Pkg 
Pkg.activate(".")
using Revise
using Pigeons 
using Statistics
using Distributions

target_rate = 2.0

@show use_exp = false

pt = pigeons(
        target = 
            use_exp ?
                Pigeons.ExpDist(target_rate) :
                Product(Normal.(zeros(Pigeons.gauss_dim), 2 * ones(Pigeons.gauss_dim))), 
        n_rounds = 10,
        n_chains = 10,
        fused_swaps = false,
        recorder_builders = [Pigeons.online_recorder_builders(); Pigeons.interpolated_log_potentials]
    )

pt = pigeons(
        target = 
            use_exp ?
                Pigeons.ExpDist(target_rate) :
                Product(Normal.(zeros(Pigeons.gauss_dim), 2 * ones(Pigeons.gauss_dim))), 
        n_rounds = 15,
        n_chains = 2,
        fused_swaps = true,
        recorder_builders = [Pigeons.online_recorder_builders(); Pigeons.interpolated_log_potentials]
    )




#@show mean(pt), var(pt)

beta = 1.0
points, cumulative = Pigeons.interpolated_log_potential_distribution(pt, beta, 0)

@show maximum(points)

fct = Pigeons.interpolate_cdf(points, cumulative)

f = first(points)
l = last(points)

analytic_rate = (1-beta) * 1 + beta * target_rate
analytic_F(x) = if x ≤ log(my_rate) 
    exp(x - log(my_rate)) 
else
    1.0
end

analytic_iF(x) = log(analytic_rate * x)

using Plots

range = 0.0001:0.0001:0.9999 
range2 = -10:0.1:10 # (f-5):0.1:(l+5)

# p1 = plot(fct, range2)
# plot!(analytic_F, range2)

# inv = Pigeons.interpolate_cdf(points, cumulative, true)
# p2 = plot(inv, range)
# plot!(analytic_iF, range)

# composition = inv ∘ fct 
# p3 = plot(composition, range2)

# plot(p1, p2, p3)


Te, dTe = Pigeons.height_mover(pt.shared.swapper, 1, 2)
#Ta, dTa, a, b = Pigeons.detailed_a_height_mover(pt.shared.swapper, 1, 2)

p1 = plot(Te, range2)
#plot!(Ta, range2)

p2 = plot(dTe, range2)
#plot!(dTa, range2)

plot(p1, p2)