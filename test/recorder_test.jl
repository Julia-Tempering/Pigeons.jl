using Pigeons
using OnlineStats
using SplittableRandoms
using MPI

maybe simplest will be to write your own allreduce based on isend/etc...
    -> ensures finer control on repro at same time..

function test_recorder(replicas, n_iters::Int)
    n_chains = n_chains_global(replicas)
    path = Pigeons.TranslatedNormalPath(2.0)
    discretization = Pigeons.discretize(path, Pigeons.equally_spaced(n_chains))
    recorder = Pigeons.Recorder(replicas)
    swapper = Pigeons.Swapper(discretization, recorder)
    for iteration in 1:n_iters
        swap!(swapper, replicas, deo(n_chains, iteration))
        for replica in locals(replicas)
            dist = discretization[replica.chain]
            new_sample = rand(replica.rng, dist)
            replica.state = new_sample
        end
    end
    reduced = Pigeons.reduced_stats(recorder)
    println(value(reduced[:swap_acceptance_pr]))
end

n_chains = 5

test_recorder(create_vector_replicas(n_chains, Ref(0.0), SplittableRandom(1) ), 10)

test_recorder(create_entangled_replicas(n_chains, Ref(0.0), SplittableRandom(1), true), 10)

