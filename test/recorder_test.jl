using Pigeons
using OnlineStats
using SplittableRandoms
using MPI

import Base.Threads.@threads


function test_recorder(replicas, n_iters::Int)
    n_chains = n_chains_global(replicas)
    path = TranslatedNormalPath(2.0)
    discretization = discretize(path, Schedule(n_chains))
    for iteration in 1:n_iters
        swap!(discretization, replicas, deo(n_chains, iteration))
        
        @threads for replica in locals(replicas)
            dist = discretization[replica.chain]
            new_sample = rand(replica.rng, dist)
            replica.state = new_sample
        end
    end
    return reduce_recorders!(replicas)
end

n_chains = 5
n_iters = 20

all_expensive_recorders = Set(keys(expensive_recorders()))

vector_replica = create_vector_replicas(
    n_chains, 
    Ref(0.0), 
    SplittableRandom(1), 
    all_expensive_recorders )

one_machine = test_recorder(vector_replica, n_iters)

mpi = test_recorder(
    create_entangled_replicas(
        n_chains, 
        Ref(0.0), 
        SplittableRandom(1), 
        true, 
        all_expensive_recorders), 
        n_iters)

@assert one_machine == mpi

# Now check that recorders get emptied properly

vector_replica2 = create_vector_replicas(
    n_chains, 
    Ref(0.0), 
    SplittableRandom(1), 
    all_expensive_recorders )


for i in eachindex(vector_replica2)
    vector_replica2[i].recorders = vector_replica[i].recorders
end

one_machine2 = test_recorder(vector_replica2, n_iters)

@assert one_machine == one_machine2