using JuliaBUGS
using AbstractPPL: getsym

# good ol' toy unidentifiable model for testing purposes
unid_model_def = @bugs begin
    for i in 1:2
        p[i] ~ dunif(0,1)
    end
    p_prod = p[1]*p[2]
    n_heads ~ dbin(p_prod, n_flips)
end
unid_target_model = compile(unid_model_def, (; n_heads=50000, n_flips=100000))
unid_target = JuliaBUGSLogPotential(unid_target_model)

@testset "JuliaBUGS: extracting prior model" begin
    unid_ref = Pigeons.default_reference(unid_target)
    unid_prior_model = unid_ref.model
    @test Set(getsym(vn) for vn in unid_prior_model.parameters) == Set((:p,))
end
