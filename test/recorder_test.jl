using Pigeons
using OnlineStats
using SplittableRandoms
using MPI



function test_recorder(replicas, n_iters::Int)
    n_chains = n_chains_global(replicas)
    path = TranslatedNormalPath(2.0)
    discretization = discretize(path, equally_spaced(n_chains))
    for iteration in 1:n_iters
        swap!(discretization, replicas, deo(n_chains, iteration))
        
        for replica in locals(replicas)
            dist = discretization[replica.chain]
            new_sample = rand(replica.rng, dist)
            replica.state = new_sample
        end
    end
    return reduced_stats(replicas)
end

n_chains = 5
n_iters = 1000

one_machine = test_recorder(create_vector_replicas(n_chains, Ref(0.0), SplittableRandom(1) ), n_iters)
mpi = test_recorder(create_entangled_replicas(n_chains, Ref(0.0), SplittableRandom(1), true), n_iters)

@assert one_machine == mpi
