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
See below for some performance evaluation results and comments.
"""
function test_swap(n_chains::Int, n_iters::Int, accept_pr::Float64, useMPI::Bool)

    GC.enable_logging(true)

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


"""
Examples stats from Sockeye

./mpi-run -p 100 -t 00:01:00 julia --project=. test/swap_test.jl --N 100 --iters 20000
Entangler initialized 1 process (without MPI)
Timing summary: 188.40296799999996 μs (526.5824745863137)
Entangler initialized 100 MPI processes
Timing summary: 5078.727238999977 μs (25379.513020933457)

1000 chains...

..over 100 processes:
./mpi-run -p 100 -t 00:05:00  julia --project=. test/swap_test.jl --N 1000 --iters 20000 --pr 0.5
Entangler initialized 1 process (without MPI)
Timing summary: 1730.854674000008 μs (583.3826974706266)
Entangler initialized 100 MPI processes
Timing summary: 39066.16417900025 μs (167071.0183463262)

...over 1000 processes (! - investigating - possibly faulty as Sockeye seemed to have problems around that time..)
[TODO: results on 1000 chains are queued at the moment]
Entangler initialized 1 process (without MPI)
Timing summary: 2031.172538 μs (944.5616995332483)
Entangler initialized 1000 MPI processes
Timing summary: 131189.92799899983 μs (630977.8558821594)

What can explain this large increase? Hypotheses include:

(1) it may be costly to create first-time connection, then since possible interactions in quadratic, we eventually get hit by this cost 
(2) we were unlucky and got one or several very slow machine
(3) GC cycles getting out of sync [this has been commented on before, see e.g. Maas et al. 'Trash Day: Coordinating Garbage Collection in Distributed Systems']

By running the test again a few days later, we obtained the same result, so (2) is excluded with reasonable probability.

I then used GC.enable_logging(true) and ran the code in single process mode. GC pauses where in the order of 10-20ms so 
    not enough to explain the large jump in runtime, so (3) is excluded as well.

This leaves (1). To test this hypotheses we ran the same code but with swap acceptance probability set to zero instead of 0.5. This leaves 
    the same number of communication events, but makes it happen between a fixed network neighbourhood structure instead of 
    the evolving network neighbourhood structure implied by non-zero swap acceptance. The results confirm that (3) is the likely culprit:

Command: julia --project=. test/swap_test.jl --iters 10000 --N 1000 --pr 0.0
Exec directory: /scratch/st-alexbou-1/Pigeons.jl/results/all/2022-11-23-22-13-34-GB7vyCFi
PBS resources: walltime=00:10:00,select=1000:ncpus=1:mpiprocs=1:mem=8gb
Git commit: 61fa0a8dc4a3315c11f116cde497e5a6f94f7d36
    Timing summary: 1965.5953419999958 μs (584.4737300777105)
    Entangler initialized 1000 MPI processes
    Timing summary: 1441.027353999992 μs (1868.1896393319637)

This is surprising since the MPI performance evaluation and MPI simulator literature [e.g. Clauss et al. 'Single Node On-Line Simulation of MPI Applications with SMPI'] 
    does not seem to highlight the fact that there is extra latency involved with creating a new connection. This may be due to the 
    fact that our sparse but evolving communication topology is distinct from typical MPI workloads, where for example for applications 
    such as PDE simulators the network neighbourhood structure is fixed at the beginning (there are exceptions, for example 
    work building distributed hash tables on top of MPI [Tsukamoto et al, 'Implementation and Evaluation of Distributed Hash Table Using MPI'], 
    but these appear more of a niche based on citation counts [2010 paper cited 4 times as of 2022]).
"""