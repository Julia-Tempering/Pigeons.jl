using JuliaBUGS

# good ol' toy unidentifiable model for testing purposes
unid_model_def = @bugs begin
    for i in 1:2
        p[i] ~ dunif(0,1)
    end
    p_prod = p[1]*p[2]
    n_heads ~ dbin(p_prod, n_flips)
end
unid_target_model = compile(unid_model_def, (; n_heads=50000, n_flips=100000))
unid_target_constrained = JuliaBUGSPath(JuliaBUGS.settrans(unid_target_model))
struct IdentityExplorer end
function Pigeons.step!(::IdentityExplorer, replica, shared) end

@testset "Basic sampling via independent MH from the prior" begin
    pt = pigeons(
        target = unid_target_constrained,
        n_chains = 2,
        explorer = IdentityExplorer(),
        record = [traces],
        extended_traces = true
    )
    # check sample_iid!
    @test isapprox(0.5, mean(v[1] for (k,v) in pt.reduced_recorders.traces if first(k)==1), rtol=0.05)
    @test isapprox(0.5, mean(v[2] for (k,v) in pt.reduced_recorders.traces if first(k)==1), rtol=0.05)

    # check log_potential evaluation with constrained version (easier, no Jacobian)
    @test all(v for (k,v) in pt.reduced_recorders.traces if first(k)==2) do v
        logpdf(
            Binomial(unid_target_model.evaluation_env.n_flips, v[1]*v[2]),
            unid_target_model.evaluation_env.n_heads
        ) == last(v)
    end
end
