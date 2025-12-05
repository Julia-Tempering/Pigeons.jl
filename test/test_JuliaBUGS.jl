import JuliaBUGS
using JuliaBUGS: @bugs, compile, settrans

include("supporting/analytic_solutions.jl")
include("supporting/mpi_test_utils.jl")
include("../examples/JuliaBUGS.jl")

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
        last(v) == logpdf(
            Binomial(unid_target_model.evaluation_env.n_flips, v[1]*v[2]),
            unid_target_model.evaluation_env.n_heads
        )
    end
end

@testset "SliceSampler on constrained and unconstrained versions" begin
    exact_logZ = unid_target_exact_logZ(
        unid_target_model.evaluation_env.n_flips,
        unid_target_model.evaluation_env.n_heads
    )
    for target in (unid_target, unid_target_constrained)
        @show target.model
        pt = pigeons(;
            target,
            explorer = SliceSampler(), 
            n_chains=7, 
            n_rounds=5
        )
        @test isapprox(Pigeons.stepping_stone(pt), exact_logZ, atol=2, rtol=0.2)
    end
end

@testset "Invariance test" begin
    uncond_target = JuliaBUGSPath(compile(unid_model_def, (;n_flips=100000)))
    res = Pigeons.invariance_test(uncond_target, SliceSampler(); condition_on=(:n_heads,)) 
    @show res.pvalues
    @test res.passed
end

@testset "Parallelism invariance using MPI" begin
    target=incomplete_count_data()
    r = pigeons(;
        target=unid_target,
        n_rounds = 5,
        n_chains = 4,
        checkpoint = true,
        checked_round = 4,
        multithreaded = true,
        on = ChildProcess(
            n_local_mpi_processes = set_n_mpis_to_one_on_windows(2),
            n_threads = 2,
            mpiexec_args = extra_mpi_args(),
            dependencies = [JuliaBUGS]
        )
    )
    pt = Pigeons.load(r)
    @test true
end

@testset "Check no NaN log potentials" begin # https://github.com/Julia-Tempering/Pigeons.jl/pull/303#issuecomment-2547306248
    target=incomplete_count_data(tau=0.01)
    pt = pigeons(target = target, n_rounds = 4, n_chains = 4, record=[traces])
    chns = Chains(pt)
    @test first(names(chns)) != Symbol("param_1") # check we're not using the default array-state name builder
end
