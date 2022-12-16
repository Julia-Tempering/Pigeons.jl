```@meta
CurrentModule = Pigeons
```


We provide in this page an overview of Non-Reversible Parallel Tempering (PT), 
[Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464), 
linking it with some key parts of the code base. 

!!! note

    Read this page if you are interested in extending Pigeons or 
    understanding how it works under the hood. 
    Reading this page is not required to use Pigeons, for that instead refer to the 
    [user guide](index.html). 



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
translate well-mixing of these univariate statistics into global mixing of ``X^{(i)}`` by 
leveraging the reference distribution(s).

### Local exploration

In the **local exploration phase**,
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
In principle, there are two equivalent ways to do a swap: the `Replica`s could exchange 
their `state` fields; or alternatively, they could exchange their `chain` fields.
Since we provide distributed implementations, we use the latter as it ensures that 
the amount of data that needs to be exchanged between two machines during a swap 
can be made very small (two floats). 
It is remarkable that this cost does not vary with the dimensionality of the state space, 
in constrast to the naive implementation which would transmit states over the network.
See [Distributed PT](distributed.html) for more information on our distributed implementation.

Both in distributed and single process mode, 
swaps are performed using the function [`swap!()`](@ref). See the documentation there for
more information.


## Basic PT algorithm

Here is a simplified example of how Algorithm 1 in [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464) 
can be implemented in Pigeons. (This example is for pedagogy and/or those interested in extending 
the library. Users of the library should instead follow higher-level instructions in [the user guide page](index.html).)

```@example simple_algos
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
const rng = SplittableRandom(1)            # specialized rng (see Distributed PT page)
const keys = recorder_keys(:index_process) # determines which statistics to keep

function simple_deo(n_iters, log_potentials)
    replicas = create_vector_replicas(n_chains, init, rng, keys)
    for iteration in 1:n_iters
        # communication phase
        swap!(log_potentials, replicas, deo(n_chains, iteration))
        # toy local exploration (in this toy e.g. we can do iid for all chains)
        @threads for replica in locals(replicas)
            distribution = log_potentials[replica.chain]
            replica.state = rand(replica.rng, distribution)
        end
    end
    return reduced_recorders!(replicas)
end

deo_result = simple_deo(100, normal_log_potentials)
p = index_process_plot(deo_result)
savefig(p, "index_process.svg"); nothing # hide
```

![](index_process.svg)

The code above illustrates the two steps needed to collect statistics from the execution of a PT algorithm: 

- We specify which statistics to collect using [`recorder_keys()`](@ref) (by 
    default, those that can be computed in constant memory only are included, 
    those that have growing memory consumption, e.g. tracking the full 
    index process as done here, need to be explicitly specified in advance).
- Using [`reduced_recorders!()`](@ref) to compile the statistics collected 
    by the different replicas.
    
An object responsible for accumulating all different types of statistics for 
one replica is called a  [`recorders`](@ref). An object accumulating one 
type of statistic for one replica is a [`recorder`](@ref). 
Each replica has a single recorders to ensure thread safety (as illustrated above 
by the use of a parallel local exploration phase using `@thread`) and to enable distributed 
computing. 


## Adaptation and schedule update

PT requires as input a discrete set of probability distribution, i.e. [`log_potentials`](@ref). 
How can those be automatically computed from just knowing the reference and target 
distributions?
This section outlines this process.

The starting point is a [`path`](@ref) object, which is a continuum of distributions. 
A [`path`](@ref) is typically obtained via [`create_path()`](@ref). 
We can also get a toy example consisting of normal distributions with varying 
precision parameters via [`scaled_normal_example()`](@ref), which is what we 
will use here.

We now move to a simplified version of Algorithms 2 and 3 in [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464) 
(again for pedagogy and/or those interested in extending the library), which are 
algorithms for adaptively discretizing a continuum of distributions.

The algorithm starts with a simple initial discretization.
Here it is one where each grid is equally spaced, being built using [`Schedule()`](@ref)
and [`discretize()`](@ref):

```@example simple_algos
# continues from the above
path = ScaledPrecisionNormalPath(dim)
schedule = Schedule(n_chains)
log_potentials = discretize(path, schedule)
nothing # hide
```

we then run one *round* of Algorithm 1, and use its output to 
compute an initial estimate of the communication barriers as defined 
in [Section 4 of Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464) 
and implemented in [`communicationbarrier()`](@ref).

```@example simple_algos
# continues from the above
deo_result = simple_deo(100, log_potentials)
barriers = communicationbarrier(deo_result, schedule)
plot(barriers.cumulativebarrier, legend = false)
xlims!(0, 1)
savefig("barrier.svg") # hide
barriers.globalbarrier
```

![](barrier.svg)

We can then create a new schedule from the cumulative communication barrier 
by following [Algorithm 2 of Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464) 
and implemented in [`Schedule()`](@ref). 
Finally, following [Algorithm 4 of Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464) 
we can iterate this process by performing several rounds of PT, each with increasing budget:

```@example simple_algos
# continues from the above

function adapt(schedule, n_iters)
    log_potentials = discretize(path, schedule)
    deo_result = simple_deo(n_iters, log_potentials)
    barriers = communicationbarrier(deo_result, schedule)
    plot!(barriers.cumulativebarrier)
    xlims!(0, 1)
    return (Schedule(n_chains, barriers.cumulativebarrier), barriers)
end

function nrpt(schedule)
    n_iters = 2
    for round_index in 1:10
        schedule, barriers = adapt(schedule, n_iters)
        n_iters *= 2
    end
    return barriers
end

plot()
barriers = nrpt(schedule)

savefig("barriers.svg"); nothing # hide
```

![](barriers.svg)

The simple normal model we are using has a [known closed-form expression](https://aip.scitation.org/doi/10.1063/1.1644093) 
for the cumulative barrier. We can use this closed-form expression to check the 
accuracy of our PT-derived approximation:

```@example simple_algos
# continues from the above
analytic = analytic_cumulativebarrier(path)
plot([analytic, barriers.cumulativebarrier], labels = ["analytic" "estimate"])
xlims!(0, 1)
savefig("compare-barriers.svg"); nothing # hide
```

![](compare-barriers.svg)