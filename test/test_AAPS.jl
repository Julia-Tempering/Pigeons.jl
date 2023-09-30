using MCMCChains

@testset "AAPS" begin
    rng = SplittableRandom(1) 
    pt = pigeons(; 
        target = Pigeons.stan_banana(1), 
        explorer = AAPS(), 
        n_chains = 1, n_rounds = 12, record = [traces])
    @show min_ess_id = minimum(ess(Chains(sample_array(pt))).nt.ess)
end
