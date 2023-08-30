```@meta
CurrentModule = Pigeons
```

# [Pigeons](@id index)

## Summary

`Pigeons` is a Julia package to approximate challenging posterior distributions, and more broadly, Lebesgue integration problems. Pigeons can be used in a multi-threaded context, and/or distributed over hundreds or thousands of MPI-communicating machines.

Pigeons supports many [different ways to specify integration/expectation problems](@ref input-overview) and 
provides [rich and configurable output](@ref output-overview). 

Pigeons' core algorithm is a distributed and parallel implementation 
of the following algorithms: 

- Non-Reversible Parallel Tempering (NRPT), 
    [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
- Variational PT, [Surjanovic et al., 2022](https://arxiv.org/abs/2206.00080). 

These algorithms achieve state-of-the-art performance for approximation 
of challenging probability distributions.


## [Installing Pigeons](@id installing-pigeons)

1. If you have not done so, install [Julia](https://julialang.org/downloads/). Julia 1.8 and higher are supported. 
2. Install `Pigeons` using

```
using Pkg; Pkg.add("Pigeons")
```


## Basic usage

Specify the target distribution and, optionally, 
parameters like random seed, etc by creating an 
[`Inputs`](@ref):

```@example example
using Pigeons

inputs = Inputs(target = toy_mvn_target(100))
```

Have a look at the [`Inputs`](@ref) documentation for an overview of the many options available to configure pigeons.
You will find information there on setting the random `seed`, 
controlling the number of iterations (via `n_rounds`), 
and many more options

Then, run PT (locally on one process) using the function [`pigeons()`](@ref):

```@example example
pt = pigeons(inputs);
nothing # hide
```

This runs PT on a 100-dimensional MVN toy example with 10 chains 
for ``2047 = 2^{11} - 1`` iterations, and 
returns a [`PT`](@ref) struct containing the results of 
this run (more later on how to access information inside 
a PT struct). Each line in the output provides information on a *round*, where the number of iteration 
per round doubles at each round and adaptation is performed 
between rounds. 

Since the above two julia lines are the most common operations in this package, creating inputs and running PT can be done in one line 
as follows:

```@example example
pt = pigeons(target = toy_mvn_target(100));
nothing # hide
```

where the `args...` passed to `pigeons` are forwarded 
to [`Inputs`](@ref).


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

- Approximating expectations of the form ``E[f(X)]``, where ``X \sim \pi``. 
    For example, the choice ``f(x) = x`` computes the mean, and 
    ``f(x) = I[x \in A]`` computes the probability of ``A`` under ``\pi``.
    See [manipulating the output of pigeons](@ref output-overview)
- Approximating the value of the normalization constant ``Z``. For 
    example, in Bayesian statistics, this corresponds to the 
    [marginal likelihood](https://en.wikipedia.org/wiki/Marginal_likelihood). See [approximation of the normalization constant](@ref output-normalization)

Pigeons shines in the following scenarios:

- When the posterior density ``\pi`` is challenging due to 
    non-convexity and/or [concentration on a 
    sub-manifolds due to unidentifiability](@ref unidentifiable-example).
- When the user needs not only ``E[f(X)]`` but also ``Z``. Many existing MCMC tools
    focus on the former and struggle to do the latter in high dimensional 
    problems. 
- When the posterior density ``\pi`` is defined over a non-standard state-space, 
    e.g. a combinatorial object such as a phylogenetic tree.
    See [defining custom explorers](@ref input-explorers) 
    and [targeting non-julian models](@ref input-nonjulian).


## How to cite Pigeons

Our team works hard to maintain and improve the Pigeons package. Please consider 
citing our work by referring to [our Pigeons paper](https://arxiv.org/abs/2308.09769).

**BibTeX code for citing Pigeons**

```
@article{surjanovic2023pigeons,
  title={Pigeons.jl: {D}istributed sampling from intractable distributions},
  author={Surjanovic, Nikola and Biron-Lattes, Miguel and Tiede, Paul and Syed, Saifuddin and Campbell, Trevor and Bouchard-C{\^o}t{\'e}, Alexandre},
  journal={arXiv:2308.09769},
  year={2023}
}
```

**APA**

Surjanovic, N., Biron-Lattes, M., Tiede, P., Syed, S., Campbell, T., & Bouchard-Côté, A. (2023). Pigeons.jl: Distributed sampling from intractable distributions. *arXiv:2308.09769.*