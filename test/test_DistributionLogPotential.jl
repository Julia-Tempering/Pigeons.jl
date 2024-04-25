using Bijectors
using DelimitedFiles

include("supporting/mpi_test_utils.jl")
n_mpis = set_n_mpis_to_one_on_windows(2)

@testset "DLP: Multivariate" begin
    function unid_log_potential(x; n_trials=100, n_successes=50)
        p1, p2 = x
        ((0 <= p1 <= 1) && (0 <= p2 <= 1)) || return typeof(p1)(-Inf)
        p = p1 * p2
        return n_successes*log(p) + (n_trials-n_successes)*log1p(-p)
    end
    Pigeons.initialization(::typeof(unid_log_potential), _, _) = [0.5, 0.5]
    ref_dist = product_distribution([Uniform(), Uniform()])
    pt = pigeons(
        target    = unid_log_potential,
        reference = DistributionLogPotential(ref_dist),
        n_chains  = 4
    )
    @test abs(Pigeons.global_barrier(pt) - 1.39) < 0.1
end
@testset "DLP: Univariate" begin
    uni_target(x) = logpdf(Normal(3,1), first(x))
    Pigeons.initialization(::typeof(uni_target), _, _) = [-3.0]
    pt = pigeons(
        target    = uni_target,
        reference = DistributionLogPotential(Normal(-3,1)),
        n_chains  = 8
    )
    @test abs(Pigeons.global_barrier(pt) - 3.15) < 0.1
end

@static if !is_windows_in_CI()
    @testset "DLP: Stan interface + iid sampling" begin
        # recreate Fig. 6 in Ballnus et al. (2017)

        # load data
        dta_path = joinpath(dirname(@__DIR__), "examples", "data", "Ballnus_et_al_2017_M1a.csv")
        dta = readdlm(dta_path, ',')
        N   = size(dta, 1)
        ts  = dta[:,1]
        ys  = dta[:,2]

        # create model target
        model_file = joinpath(dirname(@__DIR__), "examples", "stan", "mRNA.stan")
        mRNA_target = StanLogPotential(model_file, Pigeons.json(; N, ts, ys))

        # use a DistributionLogPotential based on the prior to enable iid sampling
        # note: need to work on unconstrained_parameters. We use Bijectors.transformed
        # to achieve this automatically, because their bijection for scalar Uniforms
        # is the same as the one used in Stan (logit <-> logistic)
        prior_ref = DistributionLogPotential(product_distribution(
            transformed.([Uniform(-2,1), Uniform(-5,5), Uniform(-5,5), Uniform(-5,5), Uniform(-2,2)])
        ))

        # run
        explorer = Compose(SliceSampler(), AutoMALA())
        results = pigeons(
            target = mRNA_target, 
            reference = prior_ref, 
            record = [round_trip; record_default()],
            multithreaded = false,
            n_chains = 2, # low to avoid slowing down CI; in reality, Λ ~ 6
            n_rounds = 4,
            on = ChildProcess(
                n_local_mpi_processes = n_mpis,
                n_threads = 1,
                mpiexec_args = extra_mpi_args(),
                dependencies = [Bijectors,BridgeStan]
            )
        )
        @test true

        # using PairPlots, CairoMakie
        # samples = Chains(Pigeons.load(pt))
        # fig = pairplot(samples[:,1:5,:])
        # save("myfigure.png", fig)
    end
end
