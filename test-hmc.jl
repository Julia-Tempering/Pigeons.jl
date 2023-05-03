
using Pigeons
using SplittableRandoms
using Test
using OnlineStats

rng = SplittableRandom(1)


for i in 0:3
    d = 10^i

    pigeons(target = toy_mvn_target(d), 
        explorer = Pigeons.staticHMC(0.2, 1.0, 3), 
        recorder_builders = Pigeons.online_recorder_builders())
end


return nothing


