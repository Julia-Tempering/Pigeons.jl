```@meta
CurrentModule = Pigeons
```

# [Distributed and parallel implementation of PT](@id distributed)

## Introduction

Pigeons provides an implementation of Distributed PT based on [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464), 
Algorithm 5. This page describes our strategies for addressing the challenges of implementing this distributed, 
parallelized, and randomized algorithm.

!!! note

    Read this page if you are interested in extending Pigeons or 
    understanding how it works under the hood. 
    Reading this page is not required to use Pigeons. Instead, refer to the 
    [user guide](@ref index). 

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
false negatives due to statistical error. 

Two factors tend to cause violations of Parallelism Invariance: 

- Global, thread-local and task-local random number generators (the dominant approaches to parallel
    random number generators in current languages).
- [Non-associativity of floating point operations](https://en.wikipedia.org/wiki/Associative_property#:~:text=non%2Dassociative%20magmas.-,Nonassociativity%20of%20floating%20point%20calculation,sized%20values%20are%20joined%20together). As a result, when several workers 
    perform [Distributed reduction](https://en.wikipedia.org/wiki/MapReduce) of 
    floating point values, the output of this reduction will be slightly different. 
    When these reductions are then fed into further random operations, this implies 
    two randomized algorithms with the same seed but using a different number of workers 
    will eventually arbitrarily diverge pointwise. 

One focus in the remainder of this page is to describe how our implementation sidesteps 
the two above issues while maintaining the same asymptotic runtime complexity.


## Overview of the algorithm

Let us start with a high-level picture of the distributed PT algorithm. 

The high-level code is the function [`pigeons()`](@ref) which is identical to the single-machine algorithm. 
A first difference lay in the [`replicas`](@ref) datastructure taking on a different type. Also, as promised the 
output is identical despite a vastly different swap logic: this can be checked using the `checked_round` 
argument described in the [user guide](@ref index). 
A second difference between the execution of [`pigeons()`](@ref) in single vs many machine context is the behaviour 
of [`swap!`](@ref) which is dispatched 
based on the type of 
`replicas`. 

In the following, we go over the main building block of 
our distributed PT algorithm. 


## Splittable random streams

The first building block is a splittable random stream. 
To motivate splittable random streams, consider the following example violating Parallelism Invariance.

Julia uses *task-local* random number generators, a notion which 
is related but distinct from parallelism invariance. 
We will now explain the difference between task-local random number 
generators and parallelism invariance, and why the latter is more 
advantageous for checking correctness of distributed randomized algorithms. 

Consider the following toy example:

```
using Random
import Base.Threads.@threads

println("Number of threads: $(Threads.nthreads())")

const n_iters = 10000;
result = zeros(n_iters);
Random.seed!(1);
@threads for i in 1:n_iters
    # in a real problem, do some expensive calculation here...
    result[i] = rand();
end
println("Result: $(last(result))")
```

When using 8 threads, this outputs:
```
Number of threads: 8
Result: 0.25679999169092793
```

Julia guarantees that if we rerun this code, as long as we 
are using 8 threads, we will always get the same result, 
irrespective of the multi-threading scheduling decisions 
implied by the `@threads`-loop (hence, a step ahead another 
concept known as thread-local random number generation, which
does not guarantee replicability even for a fixed number of 
threads). 

However, when we use a different number of threads (e.g., 
the key example is one thread), the result is different:
```
Number of threads: 1
Result: 0.8785201210435906
```

In this simple example above, it is not a big deal, but for our parallel tempering use case, the 
distributed version of the algorithm is significantly more complex and 
harder to debug compared to the single-threaded one. Hence we take 
task-local random number generation one step further, into **parallelism 
invariance**, which will guarantee that the output is not only 
reproducible with respect to repetitions for a fixed number of threads, 
but also for different numbers of threads. 

In our context, a first step to achieve this is to associate one random number generator to each PT chain.
To do so, we use the 
[SplittableRandoms.jl library](https://github.com/UBC-Stat-ML/SplittableRandoms.jl) which allows 
us to turn one seed into an arbitrary collection pseudo-independent random number generators. 
Since each MPI process holds a subset of the chains, we internally use the 
function [`split_slice()`](@ref) to 
get the random number generators for the slice of replicas held in a given MPI process.


## Distributed replicas

Calling [`create_entangled_replicas()`](@ref) will produce a fresh [`EntangledReplicas`](@ref), 
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

To perform distributed swaps, [`swap!()`](@ref) proceeds as follows:

1. Use the [`swap_graph`](@ref) to determine swapping partner chains,
2. translate partner chains into partner replicas (global indices) using
    `replicas.chain_to_replica_global_indices`,
3. compute [`swap_stat()`](@ref) for local chains, and use 
    [`transmit()`](@ref) to obtain partner swap stats,
4. use [`swap_decision()`](@ref) to decide if each pair should swap, and 
5. update the `replicas.chain_to_replica_global_indices` datastructure. 


## Distributed reduction

After each round of PT, the workers need to exchange richer messages
compared to the information exchanged in the swaps. 
These richer messages include swap acceptance probabilities, 
statistics to adapt a variational reference, etc. 

This part of the communication is performed using [`reduce_recorders!()`](@ref) which 
in turn calls [`all_reduce_deterministically()`](@ref) with the appropriate  
merging operations. See [`reduce_recorders!()`](@ref) and 
[`all_reduce_deterministically()`](@ref) for more information on how 
our implementation preserves Parallelism Invariance, while maintaining the logarithmic runtime of binary-tree based 
collective operations. (More precisely, `all_reduce_deterministically()` runs in time ``\log(N)`` 
when each machine holds a single chain.)

