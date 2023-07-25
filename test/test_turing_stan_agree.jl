function logdensity_and_gradient(target, x)
    g = LogDensityProblemsAD.ADgradient(:ForwardDiff, target, Pigeons.buffers()) 
    return LogDensityProblems.logdensity_and_gradient(g, x)
end

@testset "Gradient agreement" begin
    turing_target = Pigeons.toy_turing_unid_target(10)
    stan_target   = Pigeons.toy_stan_unid_target(10)

    x = [0.1, 0.1]

    turing_lp, turing_grad = logdensity_and_gradient(turing_target, x)
    stan_lp,   stan_grad   = logdensity_and_gradient(stan_target, x)  

    @test turing_lp ≈ stan_lp 
    @test turing_grad ≈ stan_grad       
end

@testset "Log-normalization agreement" begin
    @show turing_estimate = Pigeons.stepping_stone_pair(pigeons(target = Pigeons.toy_turing_unid_target(100), explorer = SliceSampler(), n_rounds = 12))
    @show stan_estimate   = Pigeons.stepping_stone_pair(pigeons(target = Pigeons.toy_stan_unid_target(100), variational = GaussianReference(), explorer = SliceSampler(), n_rounds = 12))

    for i in [1, 2]
        @test isapprox(turing_estimate[i], stan_estimate[i], rtol = 0.05)
    end
end

