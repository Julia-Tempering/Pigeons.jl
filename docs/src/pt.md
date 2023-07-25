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
    [user guide](@ref index). 


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
``\pi_1, \pi_2, \dots \pi_N``, where ``N`` can be obtained using [`n_chains()`](@ref). 
We use the terminology chain to refer to an index ``i`` of ``\pi_i``.
Typically, ``\pi_N`` coincides with the distribution of interest ``\pi`` (called the "target"), while 
``\pi_1`` is a tractable approximation that will help PT efficiently explore the 
state space (called the "reference"). 
More broadly, we assume a subset of the chains (determined by [`is_target()`](@ref)) coincide with the target, and that a subset of the chains (determined by  [`is_reference()`](@ref)) support 
efficient exploration such as i.i.d. sampling or a rapid mixing kernel. 

PT is designed so that its stationary distribution is ``\boldsymbol{\pi} = \pi_1 \times \pi_2 \times \dots \pi_N``. 
As a result, subsetting each sample to its component corresponding to ``\pi_N = \pi``, 
and applying an integrable function ``f`` to each, will lead under weak assumptions 
to Monte Carlo averages that converge to the expectation of interest ``E[f(X)]`` for 
``X \sim \pi``.


## Outline of local exploration and communication

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
`Replica`'s `state` field. The key interface controlling local exploration, [`explorer`](@ref), is 
described in more detail below. 


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
See [Distributed PT](@ref distributed) for more information on our distributed implementation.

Both in distributed and single process mode, 
swaps are performed using the function [`swap!()`](@ref). 

The key interface controlling communication, [`tempering`](@ref), is 
described in more detail below. 


## A tour of the PT meta-algorithm

A generalized version of Algorithm 1 ("one round of PT") in [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464) 
is implemented in Pigeons in [`run_one_round!()`](@ref), 
while the complete algorithm ("several adaptive rounds"), 
[Algorithm 4 of Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464), 
has a generalized implementation in [`pigeons()`](@ref). 

In the following we discuss different facets of these (meta-)algorithms.


### Storage in PT algorithms

The information stored in the execution of [`pigeons()`](@ref) 
is grouped in the struct [`PT`](@ref). 
The key fields are one pointing to a [`replicas`](@ref) and 
one to a [`Shared`](@ref). 
Briefly, [`replicas`](@ref) will store information distinct in each 
MPI process, and read-write during each 
round, while [`Shared`](@ref) is identical in all MPI processes, read only during a round, and updated only between 
rounds. 

To orchestrate the creation of [`PT`](@ref) structs, [`Inputs`](@ref) is used. Inputs fully determines the execution of a 
PT algorithm (target distribution, random seed, etc). 


### [Collecting statistics: [`recorder`](@ref) and [`recorders`](@ref)](@id collecting-statistics)

Two steps are needed to collect statistics from the execution of a PT algorithm: 

- Specifying which statistics to collect using one or several [`recorder_builder`](@ref) 
    (e.g. by 
    default, only some statistics that can be computed in constant memory  are included, 
    those that have growing memory consumption, e.g. tracking the full 
    index process as done here, need to be explicitly specified in advance).
- Then at the end of [`run_one_round!()`](@ref), [`reduce_recorders!()`](@ref)
    is called to compile the statistics collected  by the different replicas.
    
An object responsible for accumulating all different types of statistics for 
one replica is called a  [`recorders`](@ref). An object accumulating one 
type of statistic for one replica is a [`recorder`](@ref). 
Each replica has a single recorders to ensure thread safety (e.g., see 
the use of a parallel local exploration phase using `@thread` in [`explore!()`](@ref)) and to enable distributed 
computing. 


#### Using a built-in [`recorder`](@ref) 

To see the list of built-in implementations of [`recorder`](@ref), see the section "Examples of functions.." at [`recorder`](@ref). 

To specify you want to use one [`recorder`](@ref), specify it in the Vector 
argument `recorder_builders` in [`Inputs`](@ref). For example, to signal you want 
to save the full index process, use:
```@example recorders
using Pigeons

pt = pigeons(target = toy_mvn_target(1), record = [index_process]);
nothing # hide
```
You can then access the index process via 
```@example recorders
pt.reduced_recorders.index_process
```


#### Creating your own [`recorder`](@ref)

The following pieces are needed

1. Pick or create a struct `MyStruct` that will hold the information. 
2. Implement all the methods in the section "Contract" of [`recorder`](@ref) making sure to type the recorder argument as `recorder::MyStruct`. Some examples are in the same source file as [`recorder`](@ref) and/or in the same folder as `recorder.jl`.   
3. Create a [`recorder_builder`](@ref) which is simply a function such 
that when called with zero argument, creates your desired type, i.e. 
`MyStruct`. The name of this function will define the name of your [`recorder`](@ref).


### Local [`explorer`](@ref)

Typical target distributions are expected to take care of building 
their own explorers, so most users are not expected to have to 
write their own. But for non-standard target it is useful to be 
able to do so. 

Building a new explorer is done as follows: first, suppose you are planning to use a non-standard target of type `MyTargetType`

1. Pick or create a struct `MyExplorerStruct` that may contain adaptation 
    information such as step sizes for HMC or proposal bandwidth. 
    Note that explorers will need to explore not only the target 
    distribution ``\pi`` but also the intermediate ones ``\pi_i``.
2. Implement all the methods in the section "Contract" of [`explorer`](@ref) making sure to type the explorer argument as `explorer::MyExplorerStruct`. Some examples are in the same folder as the source file of [`explorer`](@ref).  
3. Define a method `default_explorer(target::MyTargetType)` which 
    should return a fresh `MyExplorerStruct` instance. 

One explorer struct will be shared by all threads, so it should be 
read-only during execution of `run_one_round!()`. 
It can be adapted between rounds. 


### Tempering 

Customizing [`communicate!()`](@ref) follows the same general steps as custom explorers, i.e.:

1. Pick or create a struct `MyTemperingStruct` that may contain adaptation 
    information such as schedule optimization. 
2. Implement all the methods in the section "Contract" of [`tempering`](@ref) making sure to type the tempering argument as `tempering::MyTemperingStruct`. For example, see [`NonReversiblePT`](@ref). 
3. Initial construction of the tempering is done via  [`create_tempering()`](@ref).


