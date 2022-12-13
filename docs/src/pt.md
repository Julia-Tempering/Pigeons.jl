```@meta
CurrentModule = Pigeons
```


We provide in this page an overview of Non-Reversible Parallel Tempering (PT), 
[Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464), 
linking it with some key parts of the code base. 


## PT augmented state space, replicas

Let ``X_n`` denote a Markov chain on state space ``\mathscr{X}`` with stationary distribution
``\pi``. 
PT is a Markov chain defined on the augmented state space ``\mathscr{X}^N``, hence 
a state has the form ``\boldsymbol{X} = (X^{(1)}, X^{(2)}, \dots, X^{(N)})``. 
Each component of ``\boldsymbol{X}`` is stored in a struct called a
[`Replica`](@ref). 

The storage of the vector of replicas ``\boldsymbol{X}``, is done via the informal 
interface [`replicas`](@ref). In the context of PT running on one computer, 
[`replicas`](@ref) is implemented with a `Vector{Replica}`. In the context 
of running PT distributed across several communicating machines, [`replicas`](@ref) 
is implemented via [`EntangledReplicas`](@ref), which stores the parts of 
``\boldsymbol{X}`` that are local to that machine as well as data structures 
required to communicate with the other machines. 

Internally, PT operates on a discrete set of distributions, 
``\pi_1, \pi_2, \dots \pi_N``, where ``N`` can be obtained using [`n_chains_global()`](@ref). 
We use the terminology chain to refer to an index ``i`` of ``\pi_i``.
Typically, ``\pi_N`` coincides with the distribution of interest ``\pi`` (called the "target"), while 
``\pi_1`` is a tractable approximation that will help PT efficiently explore the 
state space (called the "reference"). 
More broadly, we assume a subset of the chains (given by [`target_chains()`](@ref)) coincide with the target, and that a subset of the chains (given by [`reference_chains()`](@ref)) support 
efficient exploration such as i.i.d. sampling or a rapid mixing kernel. 

PT is designed so that its stationary distribution is ``\boldsymbol{\pi} = \pi_1 \times \pi_2 \times \dots \pi_N``. 
As a result, subsetting each sample to its component corresponding to ``\pi_N = \pi``, 
and applying an integrable function ``f`` to each, will lead under weak assumptions 
to Monte Carlo averages that converge to the expectation of interest ``E[f(X)]`` for 
``X \sim \pi``.

## Local exploration and communication

PT alternates between two phases, each ``\boldsymbol{\pi}``-invariant: the local 
exploration phase and the communication phase. Informally, the first phase attempts to achieve 
mixing for the univariate statistics ``\pi_i(X^{(i)})``, while the second phase attempts to 
translate well-mixing of the univariate statistics into global mixing of ``X^{(i)}`` by 
leveraging the reference distribution(s).

### Local exploration

In the **local exploration phase,**
each [`Replica`](@ref)'s state is modified using a ``\pi_i``-invariant kernel, 
where ``i`` is given by `Replica.chain`. Often, `Replica.chain` corresponds to 
an annealing parameter ``\beta_i`` but this need not be the case (see 
e.g. [Baragatti et al., 2011](https://arxiv.org/abs/1108.3423)).
The kernel can either modify `Replica.state` in-place, or modify the 
`Replica`'s `state` field.

!!! warning "TODO"

    More details about local exploration once the architecture of that 
    part of the code is more fleshed out...

### Communication

In the **communication phase**, PT proposes swaps between pairs of replicas. 
These swaps allow each replica's state to periodically visit reference chains. During these reference
visits, the state can move around the space quickly. 
In principle, there are two equivalent ways to do a swap: the `Replica`'s could exchange 
their `state` fields; or alternatively, they could exchange their `chain` fields.
Since we provide distributed implementations, we use the latter as it implies that 
amount of data exchanged between two machines during a swap can be made very small (two floats). 
This is remarkable that this cost does not vary with the dimensionality of the state space, 
in constrast to the naive implementation which would transmit states over the network.
See [Distributed PT](distributed.html) for more information on our distributed implementation.

Both in distributed and single process mode, 
swaps are performed using the function [`swap!()`](@ref), see the documentation there for
more information.


## Basic PT algorithm

Here is a simplified example of how Algorithm 1 in [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464) can be implemented in Pigeons (for pedagogy and/or those interested in extending the library; users of the library should instead follow higher-level instructions in [the home page](index.html)):

```@example simple_algos
using Pigeons
using SplittableRandoms
using Plots

# initialize replicas
const n_chains = 10
init = Ref(0.0)                      # initialize all states to zero
rng = SplittableRandom(1)            # specialized rng (see Distributed PT page)
keys = recorder_keys(:index_process) # determines which statistics to keep
replicas = create_vector_replicas(n_chains, init, rng, keys)

# initialize sequence of distributions
normal_log_potentials = translated_normal_example(n_chains)

function simple_deo(replicas, n_iters, normal_log_potentials)
    for iteration in 1:n_iters
        # communication phase
        swap!(normal_log_potentials, replicas, deo(n_chains, iteration))
        # toy local exploration (in this toy e.g. we can do iid for all chains)
        for replica in locals(replicas)
            distribution = normal_log_potentials[replica.chain]
            replica.state = rand(replica.rng, distribution)
        end
    end
    return reduced_recorder(replicas)
end

deo_result = simple_deo(replicas, 25, normal_log_potentials)
p = index_process_plot(deo_result)
savefig(p, "index_process.svg"); nothing # hide
```

![](index_process.svg)

The code above illustrates the two steps needed to collect statistics from the execution of a PT algorithm: 

- We specify which statistics to collect using [`recorder_keys()`](@ref) (by 
    default, those that can be computed in constant memory only are included, 
    those that have growing memory consumption, e.g. tracking the full 
    index process as done here, need to be explicitly specified in advance).
- Using [`reduced_recorder()`](@ref) to compile the statistics collected 
    by the different replicas.
    
An object responsible for accumulating all different types of statistics for 
one replica is called a  [`recorders`](@ref). An object accumulating one 
type of statistic for one replica is a [`recorder`](@ref). 
Each replica has a single recorders to ensure thread safety and distributed 
computing. 


## Adaptation and schedule update

