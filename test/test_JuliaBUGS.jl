using JuliaBUGS
using AbstractPPL

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

@testset "Extracting prior model" begin
    unid_ref = Pigeons.default_reference(unid_target)
    unid_prior_model = unid_ref.model
    @test Set(AbstractPPL.getsym(vn) for vn in unid_prior_model.parameters) == Set((:p,))
end

@testset "Initialization" begin
    true_init_pars = (;p = unid_target_model.evaluation_env.p)
    @test Pigeons.initialization(unid_target, SplittableRandom(1), 1) == true_init_pars
end

@testset "sample_iid!" begin
    pt = pigeons(target = unid_target, n_rounds = 0, n_chains = 1)
    ref = Pigeons.default_reference(unid_target)
    new_state = Pigeons.sample_iid!(ref, pt.replicas[1], pt.shared)
    @test pt.replicas[1].state === new_state
end

@testset "log_potential eval" begin
    # check log_potential evaluation with constrained version (easier, no Jacobian)
    unid_target_const = JuliaBUGSLogPotential(JuliaBUGS.settrans(unid_target_model))
    unid_ref_const = Pigeons.default_reference(unid_target_const)
    state = (; p = unid_target_model.evaluation_env.p)
    @test unid_target_const(state) == 
        logpdf(
            Binomial(unid_target_model.evaluation_env.n_flips,prod(state.p)),
            unid_target_model.evaluation_env.n_heads)
    @test unid_ref_const(state) == 0
end
