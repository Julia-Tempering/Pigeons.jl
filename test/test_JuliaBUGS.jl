using JuliaBUGS

include("supporting/analytic_solutions.jl")

# good ol' toy unidentifiable model for testing purposes
unid_model_def = @bugs begin
    for i in 1:2
        p[i] ~ dunif(0,1)
    end
    p_prod = p[1]*p[2]
    n_heads ~ dbin(p_prod, n_flips)
end
unid_target_model = compile(unid_model_def, (; n_heads=50000, n_flips=100000))
unid_target = JuliaBUGSPath(unid_target_model)
unid_target_constrained = JuliaBUGSPath(JuliaBUGS.settrans(unid_target_model))
struct IdentityExplorer end
function Pigeons.step!(::IdentityExplorer, replica, shared) end
exact_logZ = unid_target_exact_logZ(
    unid_target_model.evaluation_env.n_flips,
    unid_target_model.evaluation_env.n_heads
)

@testset "Basic sampling via independent MH from the prior" begin
    pt = pigeons(
        target = unid_target_constrained,
        n_chains = 8,
        explorer = IdentityExplorer(),
        record = [traces],
        extended_traces = true
    )
    # check normalizing constant
    @test isapprox(Pigeons.stepping_stone(pt), exact_logZ, rtol=0.1)
    
    # check state extraction
    # check sample_iid! produces p1,p2 ~iid U(0,1) => E[p1p2]=0.25
    @test isapprox(
        mean(prod(v.p) for (k,v) in pt.reduced_recorders.traces if first(k)==1), 
        0.25, 
        rtol=0.05
    )
    # check posterior E[p1*p2] ~ 0.5 = n_heads/n_flips
    @test isapprox(
        mean(prod(v.p) for (k,v) in pt.reduced_recorders.traces if first(k)==2), 
        0.5, 
        rtol=0.05
    )
end

# @testset "SliceSampler on constrained and unconstrained versions" begin
#     for target in (unid_target, unid_target_constrained)
#         @show target.model
#         pt = pigeons(;
#             target,
#             explorer = SliceSampler(), 
#             n_chains=7, 
#             n_rounds=5
#         )
#         @test isapprox(Pigeons.stepping_stone(pt), exact_logZ, rtol=0.1)
#     end
# end

# @testset "Invariance test" begin
#     uncond_target = JuliaBUGSPath(compile(unid_model_def, (;n_flips=100000)))
#     res = Pigeons.invariance_test(uncond_target, SliceSampler(); condition_on=(:n_heads,)) 
#     @show res.pvalues
#     @test res.passed
# end
