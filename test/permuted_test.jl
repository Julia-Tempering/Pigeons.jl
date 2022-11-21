using Pigeons
using OnlineStats
using Random
using MPI
using ArgMacros

@structarguments false Args begin
    @argumentdefault Int 37 N "--N"
    @argumentdefault Int 1000 iters "--iters"
    @argumentflag single "-s" # no MPI
end


"""
Run from runtests.jl
"""

function test_permuted(args::Args)
    size = args.N

    function shift(i)
        if i == size
            return 1
        else 
            return i + 1
        end
    end

    rng = MersenneTwister(1)
    serial = randperm(rng, size)
    e = Entangler(size; parent_communicator = (args.single ? nothing : MPI.COMM_WORLD))
    my_globals = my_global_indices(e.load)
    
    distributed = PermutedDistributedArray(serial[my_globals], e)

    @assert permuted_get(distributed, my_globals) == serial[my_globals]

    timing_stats = Series(Mean(), Variance())

    n_iters = args.iters

    for iteration in 1:n_iters

        # do changes serially
        old_serial = copy(serial)
        for i in 1:size
            serial[old_serial[i]] = shift(i)
        end

        # do the same distributedly
        t = @elapsed begin
            
            old_value = permuted_get(distributed, my_globals)
            permuted_set!(distributed, old_value, shift.(my_globals))

            @assert permuted_get(distributed, my_globals) == serial[my_globals]
        end

        if iteration > n_iters / 2
            fit!(timing_stats, t)
        end

    end 
    
    if distributed.entangler.load.my_process_index == 1
        m, v = timing_stats.stats
        mean = value(m) * 10e6
        sd = sqrt(value(v)) * 10e6
        println("Timing summary: $mean μs ($sd)")
    end

end



test_permuted(Args())