```@meta
CurrentModule = Pigeons
```

# Pigeons

Facing a challenging integration problem? Tired of waiting for hours or days for your high-dimensional, multimodal Bayesian posterior approximation? Summing over your combinatorial space is taking months? 

Try `Pigeons`: a Julia package to efficiently approximate posterior distributions, and more broadly, Lebesgue integration problems. 

Pigeons' core algorithm is a distributed and parallel implementation 
of the following algorithms: 

- Non-Reversible Parallel Tempering (NRPT), 
    [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
- Variational PT, [Surjanovic et al., 2022](https://arxiv.org/abs/2206.00080). [under construction]

These algorithms achieve state-of-the-art performance for approximation 
of challenging probability distributions.

Pigeons can be used in a multi-threaded context, and/or 
distributed over hundreds or thousands of MPI-communicating machines.


## Scope

We describe here the class of problems that can be approached using Pigeons.

Let ``\pi(x)`` denote a probability density called the **target**. 
In many problems, e.g. in Bayesian statistics, the density $\pi$ is typically 
known only up to a normalization constant, 
```math
\pi(x) = \frac{\gamma(x)}{Z},
```
where ``\gamma`` can be evaluated pointwise, but ``Z`` is unknown.
Pigeons takes as input the function ``\gamma``.

!!! terminology "log_potential"

    Since we work in log-scale, we use the terminology 
    `log_potential` as a shorthand for the 
    unnormalized log density ``\log \gamma(x)``. 
    See informal interface [`log_potential`](@ref).

Pigeons' outputs can be used for two tasks:

- Approximating expecations of the form ``E[f(X)]``, where ``X \sim \pi``. 
    For example, the choice ``f(x) = x`` computes the mean, and 
    ``f(x) = I[x \in A]`` computes the probability of ``A`` under ``\pi``.
- Approximating the value of the normalization constant ``Z``. For 
    example, in Bayesian statistics, this corresponds to the 
    [marginal likelihood](https://en.wikipedia.org/wiki/Marginal_likelihood).

Pigeons shines in the following scenarios:

- When the posterior density ``\pi`` is challenging due to 
    non-convexity and/or concentration on a 
    sub-manifolds due to unidentifiability.
- When the user needs not only ``E[f(X)]`` but also ``Z``. Many existing MCMC tools
    focus on the former and struggle to do the latter in high dimensional 
    problems. 
- When the posterior density ``\pi`` is defined over a non-standard state-space, 
    e.g. a combinatorial object such as a phylogenetic tree. 


## Installing `Pigeons`

1. If you have not done so, install [Julia](https://julialang.org/downloads/). So far, we have tested the code on Julia 1.8.x.
2. Install `Pigeons` using

```
using Pkg; Pkg.add("Pigeons")
```

## Running PT

Specify the target distribution and, optionally, 
parameters like random seed, etc by creating an 
[`Inputs`](@ref):

```@example example
using Pigeons

inputs = Inputs(target = toy_mvn_target(100))
```

See [`Inputs`](@ref) for more options. 

Then, run PT (locally on one process, but using multi-threading) using the function [`pigeons()`](@ref):

```@example example
pt = pigeons(inputs)
```

This runs PT on a 100-dimensional MVN toy example, and 
returns a [`PT`](@ref) struct containing the results of 
this run (more later on how to access information inside 
a PT struct).

Since the above two julia lines are the most common operation in this package, creating inputs and running PT can be done in one line as:

```@example example
pt = pigeons(target = toy_mvn_target(100))
```

where the `args...` passed to `pigeons` are forwarded 
to [`Inputs`](@ref).


## Accessing the output of PT

The [`PT`](@ref) struct returned by [`pigeons`](@ref) 
contains a field called `reduced_recorders`, which is just 
a NamedTuple containing `recorder`'s which can be used to collect 
arbitary statistics computed along the execution of PT. 

By default, the statistics collected use constant-memory summaries 
(i.e. constant in the number of iteration, leveraging the package [OnlineStats.jl](https://github.com/joshday/OnlineStats.jl)), however it is possible to customize which statistics to collect. 

For example, we show here how to plot the *index process*, a 
useful diagnostic to assess the efficiency of PT algorithms 
([Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464)). We use the argument `recorder_builders` to 
specify that we wish to collect the full index process:

```@example example
p = pigeons(
        target = toy_mvn_target(1), 
        recorder_builders = [index_process], 
        n_rounds = 5)
```

Then we can access the information via:

```@example example
p.reduced_recorders.index_process

using Plots
Pigeons.index_process_plot(p.reduced_recorders)
savefig("index_process_plot.svg") 
```

![](index_process_plot.svg)

Other statistics follow the same general usage, 
see [Parallel Tempering (PT)](pt.html) for 
more details. 


## Loading and resuming a checkpoint

Pigeons can write a "checkpoint" periodically 
to ensure that not more than half of the work is lost in 
the event of e.g. a server failure. This is enabled as follows:

```@example example
pt = pigeons(target = toy_mvn_target(100), checkpoint = true)
```

See [`write_checkpoint()`](@ref) for details of how this 
is accomplished in a way compatible to both the single-machine 
and MPI contexts. 
Each checkpoint is located in 
`results/all/[unique folder]/round=[x]/checkpoint`, 
with the latest run in `results/latest/[unique folder]/round=[x]/checkpoint`. 

Checkpoints are also useful when an MPI-distributed PT has been 
ran, and the user wants to load the full set of 
results in one interactive session. 

To load a checkpoint, create a [`PT`](@ref) struct by passing in the path 
string to the checkpoint folder, for example to re-load the latest checkpoint 
from the latest run:

```@example example
pt_from_checkpoint = PT("results/latest")
```


## Automatic correctness checks

It is notoriously difficult to implement correct parallel/distributed algorithms. 
One strategy we use to address this is to guarantee that the code will output 
precisely the same output no matter how many threads/machines are used. 
We describe how this is done under the hood in the page [Distributed PT](distributed.html). 

In practice, how is this useful? Let us say you developed a new target and you would like
to make sure that it works correctly in a multi-threaded environment. To do so, add a flag to indicate to "check" one of the PT rounds as follows, and 
enable checkpointing

```@example example
pigeons(target = toy_mvn_target(100), checked_round = 3, checkpoint = true)
```

The above line does the following: the PT algorithm will pause at the end of round 3, spawn 
a separate process with only one thread in it, run 3 rounds of PT with the same 
[`Inputs`](@ref) object in it, and verify that the checkpoints of the single-threaded run 
is identical to  
the one that ran in the main process. If not, an error will be raised with some 
information on where the discrepancy comes from. 
Try to pick the checked round to be small enough that it does not dominate the running time 
(since it runs in single-threaded, single-process mode), but big enough to achieve 
the same code coverage as the full algorithm. Setting it to zero (or omitting the argument), 
disable this functionality.

Did the code above actually used many threads? This depends on the value of
`Threads.nthreads()`. Julia currently does not allow you to change this value at 
runtime, so for convenience we provide the following way to run the job in a 
child process with a set number of Julia threads:

```@example example
pt_result = pigeons(target = toy_mvn_target(100), checked_round = 3, checkpoint = true, on = ChildProcess(n_threads = 4))
```

Notice that this time, instead of returning a [`PT`](@ref) struct, this time we obtain 
a [`Result`](@ref), which only holds the path where the checkpoints can be found. 
If you would like to load a result in memory, use:
```@example example
pt = load(pt_result)
```

In this case, since the model is built-in, the check passed successfully as expected. But what 
if you had a third-party target distribution that is not multi-threaded friendly? 
I.e. it may write in global variables or 
other non-thread safe construct. Then you can probably still  use your thread-naive 
target over MPI *processes*. 
For example, if the thread-unsafety comes from the use of global variables, then each 
process will have its own copy of the global variables. 

We described how MPI can be used
in the next two sections.


## Running MPI locally

To run MPI locally on one machine, using 4 MPI processes and 1 thread per process use:

```@example example
pigeons(
    target = toy_mvn_target(100), 
    checked_round = 3, 
    checkpoint = true, 
    on = ChildProcess(
            n_local_mpi_processes = 4,
            n_threads = 1))
```

Note that if `n_local_mpi_processes` exceeds the number of cores, performance 
will steeply degrade (in contrast to threads, for which performance degrades 
much more gracefully when the number of threads exceeds the number of cores). 


## Running MPI on a cluster

!!! note "The magic of distributed Parallel Tempering"

    If the dimensionality of the state space is large, you may worry that 
    the time to transmit states over the network would dominate the running time. 
    Remarkably, the size of the messages transmitted in the inner loop of our 
    algorithm does **not** depend on the state space. In a nutshell, the 
    machines only need to transmit the value of log density ratios (a single float). 
    See [Algorithm 5 in Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464)
    for details.

MPI is typically available via a cluster scheduling system. At the time of 
writing, only `PBS PRO` is supported, but more will be added. 

Follow these instructions to run MPI over several machines:

1. In the cluster login node, follow the [installation instruction as above](#Installing-Pigeons). 
2. Start Julia in the login node, and perform a one-time setup by calling [`setup_mpi()`](@ref).
3. Still in the Julia REPL running in the login node, use:

```
pigeons(
    target = toy_mvn_target(100), 
    n_chains = 1000,
    on = MPI(
        n_mpi_processes = 1000,
        n_threads = 1))
```

This will start a distributed PT algorithm with 1000 chains on 1000 MPI processes, each using one thread.


## Specification of general models

The most general way to invoke Pigeons is by specifying two ingredients: a sequence of distributions, 
``\pi_1, \pi_2, \dots, \pi_N``, and for each ``\pi_i``, a ``\pi_i``-invariant Markov transition kernel.
Typically, ``\pi_1`` is a distribution from which we can sample i.i.d. (e.g. the prior, or a variational 
approximation), while the last distribution coincides with the distribution of interest, 
$\pi_N = \pi$, the target. 
We use an informal interface called [`target`](@ref) to orchestrate the creation of the ingredients 
needed by parallel tempering algorithms. 
The main pieces to specify are [`create_state_initializer()`](@ref), to provide initial states, 
[`create_explorer`](@ref), to construct [`explorer`](@ref)'s 
which are ``\pi_i``-invariant Markov transition kernel, 
and finally, [`create_reference_log_potential()`](@ref), 
to construct ``\pi_1``. 

A range of other extension points are defined, to control 
the [`tempering`](@ref), interpolating [`path`](@ref)'s, 
adaptation, but those all have reasonable default implementations built-in. See the [Parallel Tempering (PT) page](pt.html) for more information.


## Targeting a Turing.jl model

To demonstrate how to integrate a third-party target distribution into 
Pigeons, we show in this section how to sample from target distributions defined using a [Turing.jl](https://turing.ml/stable/) model. **This integration is currently experimental.** 

We consider an unidentifiable Beta-Binomial model for instructional purposes.
Typically, MCMC samplers would have difficulty sampling from 
posterior distributions of unidentifiable models. However, Pigeons excels in this scenario
compared to traditional samplers.

First, we define the Turing model.
```@example Turing
using Turing

# *Unidentifiable* unconditioned coinflip model with `N` observations.
@model function coinflip_unidentifiable(; N::Int)
    p1 ~ Uniform(0, 1) # prior on p1
    p2 ~ Uniform(0, 1) # prior on p2
    y ~ filldist(Bernoulli(p1*p2), N) # data-generating model
    return y
end;
coinflip_unidentifiable(y::AbstractVector{<:Real}) = coinflip_unidentifiable(; N=length(y)) | (; y)

function flip_model_unidentifiable()
    p_true = 0.5; # true probability of heads is 0.5
    N = 100;
    data = rand(Bernoulli(p_true), N); # generate N data points
    return coinflip_unidentifiable(data)
end
```

Once we have defined our Turing model, it is straightforward to sample from the posterior distribution of `p1` and `p2` as follows:
```@example Turing_Pigeons
using Pigeons
model = Pigeons.flip_model_unidentifiable()
pt = pigeons(target = TuringLogPotential(model)) 
```

## Targeting a non-Julian model

Suppose you have some code implementing vanilla MCMC, written 
in an arbitrary "foreign" language such as C++, Python, R, Java, etc. 
You would like to turn this vanilla MCMC code into a Parallel Tempering 
algorithm able to harness large numbers of cores, including 
distributing this algorithm over MPI. 
However, you do not wish to learn anything about 
MPI/multi-threading/Parallel Tempering. 

Surprisingly, it is very simple to bridge such code with Pigeons. 
The only requirement on the "foreign" language is that it supports 
reading the standard in and writing to the standard out, hence 
virtually any languages can be interfaced in this fashion. 
Based on this minimalist "standard stream bridge" with worker 
processes running foreign code (one such process per replica; not 
necessarily running on the same machine), Pigeons will 
coordinate the execution of an adaptive non-reversible parallel 
tempering algorithm. 

To see how to accomplish this, see [`StreamTarget`](@ref).
A concrete example is also shown in [`BlangTarget`](@ref), which 
uses this infrastructure to run arbitrary 
code in the [Blang modelling language](https://www.stat.ubc.ca/~bouchard/blang/) over MPI.
