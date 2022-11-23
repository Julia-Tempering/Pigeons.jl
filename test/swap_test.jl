using Pigeons
using OnlineStats
using SplittableRandoms
using MPI
using ArgMacros

"""
Two ways to invoke this test:
- as a test case, see runtests.jl
- from the CLI for benchmarking, e.g. 
julia --project=. test/swap_test.jl --N 100 --iters 20000 --pr 0.5
"""

@structarguments false Args begin
    @argumentdefault Int 37 N "--N"
    @argumentdefault Int 1000 iters "--iters"
    @argumentflag single "-s" # no MPI
    @argumentdefault Float64 0.5 swap_pr "--pr"
end

"""
For testing purpose, a simple swap model where all swaps have equal acceptance probability. 
"""
struct TestSwapper 
    constant_swap_accept_pr::Float64
end
Pigeons.swapstat(swapper::TestSwapper, replica::Replica, partner_chain::Int)::Float64 = rand(replica.rng)
function Pigeons.swap_decision(swapper::TestSwapper, chain1::Int, stat1::Float64, chain2::Int, stat2::Float64)::Bool 
    uniform = chain1 < chain2 ? stat1 : stat2
    return uniform < swapper.constant_swap_accept_pr
end

"""
Examples stats from Sockeye

./mpi-run -p 100 -t 00:01:00 julia --project=. test/swap_test.jl --N 100 --iters 20000
Entangler initialized 1 process (without MPI)
Timing summary: 188.40296799999996 μs (526.5824745863137)
Entangler initialized 100 MPI processes
Timing summary: 5078.727238999977 μs (25379.513020933457)

[TODO: results on 1000 chains are queued at the moment]
Entangler initialized 1 process (without MPI)
Timing summary: 2031.172538 μs (944.5616995332483)
Entangler initialized 1000 MPI processes
Timing summary: 131189.92799899983 μs (630977.8558821594)
"""
function test_swap(n_chains::Int, n_iters::Int, accept_pr::Float64, useMPI::Bool)
    swapper = TestSwapper(accept_pr)
    rng = SplittableRandom(1)
    replicas = Replicas(n_chains, ConstantInitializer(nothing), rng, useMPI)

    timing_stats = Series(Mean(), Variance())

    for iteration in 1:n_iters
        t = @elapsed swap_round!(swapper, replicas, deo(n_chains, iteration))
    
        if iteration > n_iters / 2
            fit!(timing_stats, t)
        end
    end

    if load(replicas).my_process_index == 1
        m, v = timing_stats.stats
        mean = value(m) * 10e6
        sd = sqrt(value(v)) * 10e6
        println("Timing summary: $mean μs ($sd)")
    end

    return replicas
end

function test_swap(args::Args)
    n_chains = args.N
    n_iterations = args.iters

    # run serial
    serial_replicas = test_swap(n_chains, n_iterations, args.swap_pr, false)

    # run parallel
    parallel_replicas = test_swap(n_chains, n_iterations, args.swap_pr, !args.single)
    parallel_chains = chain.(parallel_replicas.locals)

    # check they match up
    my_globals = my_global_indices(parallel_replicas.chain_to_replica_global_indices.entangler.load)
    serial_chains = chain.(serial_replicas.locals[my_globals])
    @assert parallel_chains == serial_chains
end

test_swap(Args())