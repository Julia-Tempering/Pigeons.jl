```@meta
CurrentModule = Pigeons
```

# Distributed and parallel implementation of PT 

## Introduction

Pigeons provides an implementation of Distributed PT based on [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464), 
Algorithm 5. This page describes the challenges of implementing this distributed, 
parallelized, and randomized algorithm and how we address these challenges.

!!! note

    Read this page if you are interested in extending Pigeons or 
    understanding how it works under the hood. 
    Reading this page is not required to use Pigeons. Instead, refer to the 
    [user guide](index.html). 

In Distributed PT, one or several computers run MCMC simulations in parallel and 
communicate with each other to improve MCMC efficiency. 
We use the terminology **machine** for one of these computers, or, to be more precise, 
**[process](https://en.wikipedia.org/wiki/Process_(computing))**.
In the typical setting, each machine will run one process, since our implementation also supports 
the use of several Julia **[threads](https://docs.julialang.org/en/v1/manual/multi-threading/)**.

Pigeons is designed so that it is suitable in all these scenarios:

1. one machine running PT on one thread,
2. one machine running PT on several threads,
3. several machines running PT, each using one thread, and
4. several machines running PT, each using several threads.

Ensuring code correctness at the intersection of randomized, parallel, and distributed algorithms is a challenge. 
To address this challenge, we designed Pigeons based on the following principle:

!!! note "Parallelism Invariance"

    The output of Pigeons is invariant to the number of machines and/or threads.
 

In other words, if $X_{m, t}(s)$ denotes the output of Pigeons when provided $m$ machines, $t$ threads 
per machine, and random seed $s$,
we guarantee that $X_{m, t}(s) = X_{m', t'}(s)$ for all $m', t'$. 

Without explicitly keeping Parallelism Invariance in mind during software construction, 
parallel/distributed implementations of randomized algorithms will 
typically only guarantee $E[X_{m, t}] = E[X_{m', t'}]$ for all $m, m', t, t'$.
While equality in distribution is technically 
sufficient, the stronger pointwise equality required by Parallelism Invariance makes 
debugging and software validation considerably easier. 
This is because the developer can first focus on the fully serial randomized algorithm, 
and then use it as an easy-to-compare gold-standard reference for parallel/distributed 
implementations. 
This strategy is used extensively in Pigeons to ensure correctness. 
In contrast, testing equality in distribution, while possible (e.g., see 
[Geweke, 2004](https://www.jstor.org/stable/27590449#metadata_info_tab_contents)), incurs additional 
false negative due to statistical error. 

Two factors tend to cause violations of Parallelism Invariance: 

- Thread-local random number generators (which is unfortunately the default approach to parallel
    random number generators in many languages [including Julia](https://docs.julialang.org/en/v1/stdlib/Random/#Random.seed!)).
- [Non-associativity of floating point operations](https://en.wikipedia.org/wiki/Associative_property#:~:text=non%2Dassociative%20magmas.-,Nonassociativity%20of%20floating%20point%20calculation,sized%20values%20are%20joined%20together). As a result, when several workers 
    perform [Distributed reduction](https://en.wikipedia.org/wiki/MapReduce) of 
    floating point values, the output of this reduction will be slightly different. 
    When these reductions are then fed into further random operations, this implies 
    two randomized algorithms with the same seed but using a different number of workers 
    will eventually arbitrarily diverge pointwise. 

One focus in the remainder of this page is to describe how our implementation sidesteps 
the two above issues while maintaining the same asymptotic runtime complexity.


## Overview of the algorithm

Let us start with a high-level picture of the basic distributed PT algorithm:

```@example simple_distributed_algos
using Pigeons
using SplittableRandoms
using Plots
import Base.Threads.@threads

const n_chains = 20

# initialize sequence of distributions
const dim = 8
const normal_log_potentials = scaled_normal_example(n_chains, dim)

# initialize replicas
const init = Ref(zeros(dim))               # initialize all states to zero
const rng = SplittableRandom(1)            
const keys = recorder_keys(:index_process) # determines which statistics to keep

function simple_distributed_deo(n_iters, log_potentials)
    replicas = create_entangled_replicas(n_chains, init, rng, true, keys)
    for iteration in 1:n_iters
        # communication phase
        swap!(log_potentials, replicas, deo(n_chains, iteration))
        # toy local exploration (in this toy e.g. we can do iid for all chains)
        @threads for replica in locals(replicas)
            distribution = log_potentials[replica.chain]
            replica.state = rand(replica.rng, distribution)
        end
    end
    return reduced_recorders(replicas)
end

deo_result = simple_distributed_deo(100, normal_log_potentials)
p = index_process_plot(deo_result)
savefig(p, "index_process_dist.svg"); nothing # hide
```

![](index_process_dist.svg)

Notice it is almost identical to the single-machine algorithm [presented earlier](pt.html#Basic-PT-algorithm) with the only difference being [`create_vector_replicas`](@ref) is 
replaced by [`create_entangled_replicas`](@ref). Also, as promised the 
output is identical despite a vastly different swap logic. 
Indeed, beyond the superficial syntactic similarities between the single process and 
distributed code, the behavious of [`swap!`](@ref) is quite different due the changing type 
of `replica` controlling multiple dispatch. 

In the following, after introducing a splittable random streams implementation and the distributed replicas datastructure, we discuss the key constructs that induce communication between processes in the above code: [`swap!`](@ref) and [`reduced_recorders`](@ref). 


## Splittable random streams

To motivate splittable random streams, consider the following example to illustrate 
how [thread-local random number generators](https://docs.julialang.org/en/v1/stdlib/Random/#Random.seed!) break Parallelism Invariance:

```@example break_pi
using Pigeons
using SplittableRandoms
using Random
import Base.Threads.@threads

println("Number of threads: $(Threads.nthreads())")

const n_iters = 10000
result = zeros(n_iters)
Random.seed!(1)
@threads for i in 1:n_iters
    # in a real problem, do some expensive calculation here...
    result[i] = rand()
end
println("Multi-threaded: $(last(result))")

Random.seed!(1)
for i in 1:n_iters
    # in a real problem, do some expensive calculation here...
    result[i] = rand()
end
println("Single-threaded: $(last(result))")
```

Unless only one thread is used, the two results will be different with 
high probability. 

To work around this, we associate one random number generator to each PT chain instead 
of one per thread. 

To do so, we use the 
[SplittableRandoms.jl library](https://github.com/UBC-Stat-ML/SplittableRandoms.jl) which allows 
us to turn one seed into several pseudo-independent random number generators. 
Since each MPI process holds a subset of the chains, we internally use the 
function [`split_slice()`](@ref) to 
get the random number generators for the slice of replicas held in a given MPI process.


## Distributed replicas

Calling [`create_entangled_replicas`](@ref) will produce a fresh [`EntangledReplicas`](@ref), 
taking care of distributed random seed splitting internally. 
An `EntangledReplicas` contains the list of replicas that are local to the machine, in addition
to three data structures allowing distributed communication: 
a [`LoadBalance`](@ref) which keeps track of 
how to split work across machines; an [`Entangler`](@ref), which encapsulates MPI calls; 
and a [`PermutedDistributedArray`](@ref), which  
maps chain indices to replica indices.
These datastructures can be obtained using [`load()`](@ref), [`entangler()`](@ref), and 
`replicas.chain_to_replica_global_indices` respectively.


## Distributed swaps


## Distributed reduction

