include("supporting/HetPrecisionNormalLogPotential.jl")
using MCMCChains

@testset "AAPS" begin
    rng = SplittableRandom(1)
    target = HetPrecisionNormalLogPotential(2. .^(-5:5))
    pt = pigeons(; 
            target, 
            explorer = AAPS(), 
            n_chains = 1, n_rounds = 12, record = [traces])
    @show min_ess_id = minimum(ess(Chains(sample_array(pt))).nt.ess)
end
