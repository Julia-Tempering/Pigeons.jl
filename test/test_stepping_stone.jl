@testset "Stepping-stone (2 legs)" begin

    pt = pigeons(
            target = Pigeons.toy_turing_unid_target(), 
            variational = GaussianReference(), 
            n_chains_variational = 10, 
            n_rounds = 10)

    truth = -11.9#.. based on: stepping_stone(pigeons(target = Pigeons.toy_turing_unid_target(), n_rounds = 17))
    @test isapprox(Pigeons.stepping_stone(pt), truth, rtol = 0.05)
end

@testset "Stepping-stone (1 leg)" begin
    for explorer in [AutoMALA(), SliceSampler()]
        pt = pigeons(; 
                target = toy_mvn_target(10), 
                explorer, 
                n_rounds = 15);
        p = Pigeons.stepping_stone_pair(pt)
        # truth ≈ -11.51292546497023
        truth = Pigeons.analytic_lognormalization(toy_mvn_target(10))
        # calibrated so that e.g. skipping the AutoMALA reversibility check would yield an error
        @test abs(p[1] - truth) < 0.2 
        @test abs(p[2] - truth) < 0.2
    end
end


