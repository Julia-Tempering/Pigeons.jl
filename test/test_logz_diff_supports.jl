@testset "Log z with different support for target and ref" begin
    pt = pigeons(target = DistributionLogPotential(Uniform(-2, 2)), reference = DistributionLogPotential(Uniform(0, 2)), n_rounds = 10, n_chains = 4)
    pt = pigeons(target = DistributionLogPotential(Uniform(0, 2)), reference = DistributionLogPotential(Uniform(-2, 2)), n_rounds = 10, n_chains = 4)
end