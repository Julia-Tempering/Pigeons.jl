include("supporting/HetPrecisionNormalLogPotential.jl")
using MCMCChains

aaps(target, preconditioner) =
    pigeons(; 
        target, 
        explorer = AAPS(preconditioner = preconditioner), 
        n_chains = 1, n_rounds = 12, record = [traces])

@testset "AAPS" begin
    rng = SplittableRandom(1)
    target = HetPrecisionNormalLogPotential(ones(10))
    pt = aaps(target, Pigeons.IdentityPreconditioner())
    @show min_ess_id = minimum(ess(Chains(sample_array(pt))).nt.ess)
end
