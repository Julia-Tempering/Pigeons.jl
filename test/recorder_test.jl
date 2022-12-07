using Pigeons
using OnlineStats
using SplittableRandoms
using MPI



function test_recorder(replicas, n_iters::Int)
    n_chains = n_chains_global(replicas)
    path = Pigeons.TranslatedNormalPath(2.0)
    discretization = Pigeons.discretize(path, Pigeons.equally_spaced(n_chains))
    for iteration in 1:n_iters
        swap!(discretization, replicas, deo(n_chains, iteration))
        
        for replica in locals(replicas)
            dist = discretization[replica.chain]
            new_sample = rand(replica.rng, dist)
            replica.state = new_sample
        end
    end
    reduced = Pigeons.reduced_stats(replicas)
    println(Pigeons.state.(locals(replicas)))
    println(value(reduced[:swap_acceptance_pr]))
    println("---")
end

n_chains = 5

test_recorder(create_vector_replicas(n_chains, Ref(0.0), SplittableRandom(1) ), 20)
test_recorder(create_vector_replicas(n_chains, Ref(0.0), SplittableRandom(1) ), 20)


test_recorder(create_entangled_replicas(n_chains, Ref(0.0), SplittableRandom(1), true), 20)
test_recorder(create_entangled_replicas(n_chains, Ref(0.0), SplittableRandom(1), true), 20)


