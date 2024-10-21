@testset "Two legs schedule adaptation" begin
    n_rounds = 10
    n_chains = 10
    pt_2_legs = pigeons(;
                    target = Pigeons.toy_turing_unid_target(), 
                    variational = GaussianReference(first_tuning_round = n_rounds + 1), # never activate
                    n_chains_variational = n_chains, 
                    n_chains,
                    n_rounds)

    pt_1_leg  = pigeons(;
                    target = Pigeons.toy_turing_unid_target(), 
                    variational = GaussianReference(first_tuning_round = n_rounds + 1), # never activate
                    n_chains_variational = 0, 
                    n_chains, 
                    n_rounds)

        
    @show gcb_1 = Pigeons.global_barrier(pt_1_leg.shared.tempering)
    @show gcb_2_1 = Pigeons.global_barrier(pt_2_legs.shared.tempering)
    @show gcb_2_2 = Pigeons.global_barrier_variational(pt_2_legs.shared.tempering)
    
    truth = 3.5 # based on 15 rounds

    for approx in [gcb_1, gcb_2_1, gcb_2_2]
        @test isapprox(approx, truth, atol = 0.1)
    end

    @testset "Issue #290" begin
        # test: if multiple targets exist, they should live on different legs
        idx_targets = Pigeons.target_chains(pt_2_legs)
        indexer = pt_2_legs.shared.tempering.indexer
        n_distinct_legs = length(Set(last(indexer.i2t[idx]) for idx in idx_targets))
        @test length(idx_targets) == n_distinct_legs
    end
end