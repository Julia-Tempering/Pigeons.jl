include("supporting/analytic_solutions.jl")

@testset "Stepping-stone (2 legs)" begin
    target = Pigeons.toy_turing_unid_target()
    pt = pigeons(
            target = target, 
            variational = GaussianReference(), 
            n_chains_variational = 7,
            n_chains = 8)

    truth = unid_target_exact_logZ(target)
    @test isapprox(Pigeons.stepping_stone(pt), truth, rtol = 0.05)
end

@testset "Stepping-stone (1 leg)" begin
    for explorer in [AutoMALA(), SliceSampler()]
        pt = pigeons(; 
                target = toy_mvn_target(10), 
                explorer,
                n_chains = 6, 
                n_rounds = 12);
        p = Pigeons.stepping_stone_pair(pt)
        truth = Pigeons.analytic_lognormalization(toy_mvn_target(10))
        # calibrated so that e.g. skipping the AutoMALA reversibility check would yield an error
        @test abs(p[1] - truth) < 0.2 
        @test abs(p[2] - truth) < 0.2
    end
end


