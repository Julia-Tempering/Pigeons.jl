
using Pigeons
using SplittableRandoms
using Test
using OnlineStats
using Distributions 

rho = 0.995

pigeons(target = Pigeons.bivariate_normal(1.0, 1.0, rho), 
    explorer = Pigeons.static_HMC(0.1, 1.0, 3), 
    recorder_builders = Pigeons.online_recorder_builders())

pigeons(target = Pigeons.bivariate_normal(1.0, 1.0, rho), 
    explorer = Pigeons.HMC(), 
    recorder_builders = Pigeons.online_recorder_builders())


return nothing


