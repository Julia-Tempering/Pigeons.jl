```@meta
CurrentModule = Pigeons
```

# Pigeons

Pigeons' core algorithm is a distributed and parallel implementation 
of the following algorithms: 

- Non-Reversible Parallel Tempering (NRPT), 
    [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
- Variational PT, [Surjanovic et al, 2022](https://arxiv.org/abs/2206.00080).

Pigeons can be used in a multi-threaded context, and/or 
distributed over hundreds or thousands of MPI-communicating machines.


## Goals

We describe here the class of problems that can be approached using Pigeons.

Let ``\pi(x)`` denote a probability density. 
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


## Example

!!! warning "TODO"

    Later on, once we have interfaces with some PPLs, write some user-facing examples, 
    showing the key capabilities


## Specification of general models

The most general way to invoke Pigeons is by specifying two ingredients: a sequence of distributions, 
``\pi_1, \pi_2, \dots, \pi_N``, and for each ``\pi_i``, a ``\pi_i``-invariant Markov transition kernel.
Typically, $\pi_1$ is a distribution from which we can sample i.i.d. (e.g. the prior, or a variational 
approximation), while the last distribution coincides with the distribution of interest, 
$\pi_N = \pi$. 
This sequence of distributions is specified using the informal interface [`log_potentials`](@ref). 

!!! warning "TODO"

    Add instructions for Markov transition kernels, and example code.




