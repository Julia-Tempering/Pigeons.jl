
using Pigeons
using SplittableRandoms
using Test
using OnlineStats

rng = SplittableRandom(1)

my_target = Pigeons.HetPrecisionNormalLogPotential([5.0, 1.1]) 
my_target_variance = 1.0 ./ my_target.precisions 
my_target_std_dev = sqrt.(my_target_variance)
some_cond = 
    #[1.0, 1.0] 
    [2.3, 0.8]

x = randn(rng, 2)


n_leaps = 40

recorders = (; directional_second_derivatives =  GroupBy(Int, Extrema()))

replica = Pigeons.Replica(nothing, 1, rng, recorders, 1)

v = randn(rng, 2)
for i in 1:100
    Pigeons.hamiltonian_dynamics!(my_target, some_cond, x, v, 0.1, n_leaps, replica)
    global v = randn(rng, 2)
end

@show replica.recorders.directional_second_derivatives


return nothing


