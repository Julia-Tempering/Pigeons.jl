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

See some timing results at end of file.
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


"""
Command: julia --project=. test/permuted_test.jl --iters 10000 --N 1000
Exec directory: /scratch/st-alexbou-1/Pigeons.jl/results/all/2022-11-23-19-59-01-m1LA6DS0
PBS resources: walltime=00:01:00,select=1000:ncpus=1:mpiprocs=1:mem=8gb
Git commit: 61fa0a8dc4a3315c11f116cde497e5a6f94f7d36

Entangler initialized 1000 MPI processes
Timing summary: 6569.785057999984 μs (18385.331459525063)
"""

nothing