using Pigeons
using OnlineStats
using Random
using MPI
using ArgMacros

@structarguments false Args begin
    @argumentdefault Int 37 N "--N"
    @argumentdefault Int 1000 iters "--iters"
end


"""
Run from runtests.jl
"""

function test_reduce(args::Args)
    size = args.N
    rng = MersenneTwister(1)
    e = Entangler(size)
    my_globals = my_global_indices(e.load)

    local_e = Entangler(size; parent_communicator = nothing)
    
    timing_stats = Series(Mean(), Variance())

    n_iters = args.iters

    for iteration in 1:n_iters

        list = rand(rng, size)

        base_reduce = reduce(+, list)

        slice = list[my_globals]
        reduce_single = all_reduce_deterministically(+, list, local_e)

        # do the same distributedly
        t = @elapsed begin
            
            parallel = all_reduce_deterministically(+, slice, e)
            @assert base_reduce ≈ parallel
            @assert reduce_single == parallel
        end

        if iteration > n_iters / 2
            fit!(timing_stats, t)
        end

    end 
    
    if e.load.my_process_index == 1
        m, v = timing_stats.stats
        mean = value(m) * 10e6
        sd = sqrt(value(v)) * 10e6
        println("Timing summary: $mean μs ($sd)")
    end

end



test_reduce(Args())


nothing