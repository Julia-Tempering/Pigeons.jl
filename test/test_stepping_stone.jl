@testset "Stepping-stone+explorers" begin
    for explorer in [AutoMALA(), SliceSampler()]
        pt = pigeons(; target = toy_mvn_target(10), explorer, n_rounds = 15);
        p = stepping_stone_pair(pt)
        # truth ≈ -11.51292546497023
        truth = Pigeons.analytic_lognormalization(toy_mvn_target(10))
        # calibrated so that e.g. skipping the AutoMALA reversibility check would yield an error
        @test abs(p[1] - truth) < 0.2 
        @test abs(p[2] - truth) < 0.2
    end
end