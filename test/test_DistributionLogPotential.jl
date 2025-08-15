using Bijectors
using DelimitedFiles

include("supporting/mpi_test_utils.jl")
include("supporting/rna-example.jl")
n_mpis = set_n_mpis_to_one_on_windows(2)

@testset "DLP: Multivariate" begin
    function unid_log_potential(x; n_trials=100, n_successes=50)
        p1, p2 = x
        ((0 <= p1 <= 1) && (0 <= p2 <= 1)) || return typeof(p1)(-Inf)
        p = p1 * p2
        return n_successes*log(p) + (n_trials-n_successes)*log1p(-p)
    end
    Pigeons.initialization(::typeof(unid_log_potential), ::AbstractRNG, ::Int64) = [0.5, 0.5]
    ref_dist = product_distribution([Uniform(), Uniform()])
    pt = pigeons(
        target    = unid_log_potential,
        reference = DistributionLogPotential(ref_dist),
        n_chains  = 4
    )
    @test abs(Pigeons.global_barrier(pt) - 1.39) < 0.1
end
@testset "DLP: Univariate" begin
    uni_target = DistributionLogPotential(Normal(3,1))
    pt = pigeons(
        target    = uni_target,
        reference = DistributionLogPotential(Normal(-3,1)),
        n_chains  = 8
    )
    @test abs(Pigeons.global_barrier(pt) - 3.15) < 0.1
end

@static if !is_windows_in_CI()
    @testset "DLP: Stan interface + iid sampling" begin

        # Example of non-standard interpolation: first prior to a subsampling of 10 observations, then to full

        mRNA_target = rna_example([0, 10, typemax(Int)])

        # run
        explorer = Compose(SliceSampler(), AutoMALA())
        results = pigeons(
            target = mRNA_target, 
            record = [round_trip; record_default()],
            multithreaded = false,
            n_chains = 2, # low to avoid slowing down CI; in reality, Λ ~ 6
            n_rounds = 4,
            on = ChildProcess(
                n_local_mpi_processes = n_mpis,
                n_threads = 1,
                mpiexec_args = extra_mpi_args(),
                dependencies = [Bijectors,BridgeStan,ForwardDiff]
            )
        )
        @test true

        # using PairPlots, CairoMakie
        # samples = Chains(Pigeons.load(pt))
        # fig = pairplot(samples[:,1:5,:])
        # save("myfigure.png", fig)
    end
end
