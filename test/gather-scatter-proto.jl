using Pigeons
using OnlineStats
using Random
using MPI
using ArgMacros

"""
Two ways to invoke this test:
- as a test case, see runtests.jl
- from the CLI for benchmarking, e.g. 
julia --project=. test/swap_test.jl --N 100 --iters 20000 --pr 0.5
"""

@structarguments false Args begin
    @argumentdefault Int 1000 iters "--iters"
end

function gs_swap(comm, rank, comm_size, rng)
    
    suff_stat = rand(rng)
    #println("node $rank : $suff_stat")

    result = MPI.Gather(suff_stat, comm)

    if rank == 0
        #println("gathered: $result")
        for i in eachindex(result)
            result[i] = result[i] + 1
        end
        #println("altered to: $result")
    end

    mine = Ref{Float64}()
    MPI.Scatter!(result, mine, comm)
    # if rank == 0
    #     mine[] = result[1]
    # end
    println("$rank -> $(mine[])")
    #mine = MPI.Scatter(result, )

end

function test_swap(args)

    MPI.Init()

    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)
    comm_size = MPI.Comm_size(comm)

    rng = MersenneTwister(rank + 1)

    timing_stats = Series(Mean(), Variance())

    for iteration in 1:args.iters
        t = @elapsed gs_swap(comm, rank, comm_size, rng)
    
        if iteration > args.iters / 2
            fit!(timing_stats, t)
        end
    end

    if rank == 0
        m, v = timing_stats.stats
        mean = value(m) * 10e6
        sd = sqrt(value(v)) * 10e6
        println("Timing summary: $mean μs ($sd)")
    end

end

test_swap(Args())