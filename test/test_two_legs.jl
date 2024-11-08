@testset "Test StabilizedPT machinery" begin
    n_rounds = 10
    n_chains = 8
    n_chains_variational = 7
    pt_2_legs = pigeons(;
                    target = Pigeons.toy_turing_unid_target(), 
                    variational = GaussianReference(first_tuning_round = n_rounds + 1), # never activate
                    n_chains_variational = n_chains_variational, 
                    n_chains,
                    n_rounds)

    pt_1_leg  = pigeons(;
                    target = Pigeons.toy_turing_unid_target(), 
                    variational = GaussianReference(first_tuning_round = n_rounds + 1), # never activate
                    n_chains_variational = 0, 
                    n_chains, 
                    n_rounds)

    @testset "Two legs schedule adaptation" begin
        @show gcb_1 = Pigeons.global_barrier(pt_1_leg.shared.tempering)
        @show gcb_2_1 = Pigeons.global_barrier(pt_2_legs.shared.tempering)
        @show gcb_2_2 = Pigeons.global_barrier_variational(pt_2_legs.shared.tempering)
        truth = 3.5 # based on 15 rounds
        for approx in [gcb_1, gcb_2_1, gcb_2_2]
            @test isapprox(approx, truth, rtol = 0.1)
        end
    end
    
    @testset "Issue #290" begin
        n = Pigeons.n_chains(pt_2_legs.inputs)
        idxs_targets = Pigeons.target_chains(pt_2_legs)
        idxs_refs = (i for i in 1:n if Pigeons.is_reference(pt_2_legs.shared.tempering.swap_graphs, i))
        indexer = pt_2_legs.shared.tempering.indexer
        @test isempty(intersect(idxs_refs, idxs_targets)) # targets and references should be different
        # test: if multiple references/targets exist, they should live on different legs
        for idxs in (idxs_targets, idxs_refs)
            n_distinct_legs = length(Set(last(indexer.i2t[idx]) for idx in idxs))
            @test length(collect(idxs)) == n_distinct_legs
        end
    end
end