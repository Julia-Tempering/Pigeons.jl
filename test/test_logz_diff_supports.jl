@testset "Log z with different support for target and ref" begin

    pt = pigeons(target = DistributionLogPotential(Uniform(-2, 2)), reference = DistributionLogPotential(Normal(0, 1)), n_rounds = 14)
end