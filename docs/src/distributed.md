```@meta
CurrentModule = Pigeons
```

# Distributed and parallel implementation of PT 

## Introduction

Pigeons provides an implementation of Distributed PT based on [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464), Algorithm 5. 
This page documents our implementation.

In Distributed PT, one or several computers run MCMC simulations in parallel and communicate with each other 
to improve MCMC efficiency. 
We use the terminology **machine** for one of these computers, or, to be more precise, 
**[process](https://en.wikipedia.org/wiki/Process_(computing))**.
In typical situation, each machine will run one process, since our implementation also supports 
the use of several Julia **[threads](https://docs.julialang.org/en/v1/manual/multi-threading/)**.

Pigeons is designed so that it is suitable in all these scenarios:

1. one machine running PT on one thread,
2. one machine running PT on several threads,
3. several machines running PT, each using one thread,
4. several machines running PT, each using several threads.

Ensuring code correctness at the intersection of randomized, parallel and distributed algorithms is a challenge. 
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
and then use it as an easy to compare gold-standard reference for parallel/distributed 
implementations. 
This strategy is used extensively in Pigeons to ensure correctness. 
In contrast, testing equality in distribution, while possible (e.g., see 
[Geweke, 2004](https://www.jstor.org/stable/27590449#metadata_info_tab_contents)), incurs additional 
false positive error due to statistical error. 

Two factors tend to cause violations of Parallelism Invariance: 

- Thread-local random number generators (which is unfortunately the default approach to parallel
    random number generators in many languages [including Julia](https://docs.julialang.org/en/v1/stdlib/Random/#Random.seed!)).
- [Non-associativity of floating point operations](https://en.wikipedia.org/wiki/Associative_property#:~:text=non%2Dassociative%20magmas.-,Nonassociativity%20of%20floating%20point%20calculation,sized%20values%20are%20joined%20together). As a result, when several workers 
    perform [Distributed reduction](https://en.wikipedia.org/wiki/MapReduce) of floating point values, the output of this 
    reduction will be slightly different. When these reductions are then fed into further random operations, this implies 
    two randomized algorithms with the same seed but using different number of workers will eventually arbitrarily diverge pointwise. 

One focus in the remaining of this page is to describe how our implementation sidesteps the two above issues while 
maintaining the same asymptotic runtime complexity.


## Overview of the algorithm

We start with a some terminology and then provide an overview of distributed/parallel PT, focussing on 
the parts that involve communication between machines and/or threads. 

Let $X_n$ denote a Markov chain with state space `S`. 

We refer the reader to [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464) for more 
background on PT algorithms. 








- [Replica](@ref): a point in the state space. **add doc right here instead?**

```@docs
Pigeons.Replica
```



**show pic**

**replicas**

