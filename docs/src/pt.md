```@meta
CurrentModule = Pigeons
```


## Introduction

We provide in this page an overview of Non-Reversible Parallel Tempering (PT), 
[Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464), 
linking it with some key parts of the code base. 

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

PT alternates between two phases, each ``\boldsymbol{\pi}``-invariant: the local 
exploration phase and the communication phase. Informally, the first phase attempts to achieve 
mixing for the univariate statistics ``\pi_i(X^{(i)})``, while the second phase attempts to 
translate well-mixing of the univariate statistics into global mixing of ``X^{(i)}`` by 
leveraging the reference distribution(s).

More precisely, in the **local exploration phase,**
each [`Replica`](@ref)'s state is modified using a ``\pi_i``-invariant kernel, 
where ``i`` is given by `Replica.chain`. Often, `Replica.chain` corresponds to 
an annealing parameter ``\beta_i`` but this need not be the case (see 
e.g. [Baragatti et al., 2011](https://arxiv.org/abs/1108.3423)).
The kernel can either modify `Replica.state` in-place, or modify the 
`Replica`'s `state` field.

!!! warning "TODO"

    More details about local exploration once the architecture of that 
    part of the code is more fleshed out...

In the **communication phase**, PT proposes swaps between pairs of replicas. 
These swaps allow the state to periodically visit reference chains. During these reference
visits, the state can move around the space quickly. 



**pseudo-code: first just PT**

**pair_swapper**

**figure of swaps**

**pseudo-code: rounds/adaptation**