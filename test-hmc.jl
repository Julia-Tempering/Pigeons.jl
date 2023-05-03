
using Pigeons
using SplittableRandoms
using Test
using OnlineStats

rng = SplittableRandom(1)

hmc_adapt_only_eps() = HMC(0.2, 1.0, 3, false, true, nothing, nothing, nothing)


pt = pigeons(target = Pigeons.ScaledPrecisionNormalPath(1.0, 100.0, 1), 
        recorder_builders = Pigeons.online_recorder_builders(), 
        explorer = hmc_adapt_only_eps())


return nothing


