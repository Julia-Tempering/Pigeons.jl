```@meta
CurrentModule = Pigeons
```

# [Approximation of the normalization constant](@id output-normalization)

## Background

Let ``\pi(x)`` denote a probability density called the **target**. 
In many problems, e.g. in Bayesian statistics, the density $\pi$ is typically 
known only up to a normalization constant, 
```math
\pi(x) = \frac{\gamma(x)}{Z},
```
where ``\gamma`` can be evaluated pointwise, but ``Z`` is unknown.

In many applications, it is useful to approximate the constant ``Z``. For  example, in Bayesian statistics, this corresponds to the 
[marginal likelihood](https://en.wikipedia.org/wiki/Marginal_likelihood), and it is used for model selection. 

## Normalization constant approximation in Pigeons

As a side-product of parallel tempering, we automatically obtain an approximation of the logarithm of the normalization constant ``\log Z``. This is done automatically using the 
[stepping stone estimator](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3038348/) computed in [`stepping_stone()`](@ref). 

It is shown in the [standard output report](@ref output-reports) produced at each round:

```@example constants
using Pigeons

# example target: Binomial likelihood with parameter p = p1 * p2
an_unidentifiable_model = Pigeons.toy_turing_unid_target(100, 50)

pt = pigeons(target = an_unidentifiable_model)

nothing # hide
```

and can also be accessed using:

```@example constants
stepping_stone(pt)
```

## From ratios to normalization constants

To be more precise, the steppping stone estimator computes the 
log of the *ratio*, ``\log (Z_1/ Z_0)`` where ``Z_1`` and ``Z_0`` are the normalization constants of the target and reference respectively. 

Hence to estimate ``\log Z_1`` the reference distribution ``\pi_1`` should have a known normalization constant. In cases where the reference is a proper prior distribution, for example in Turing.jl models, this is typically the case. 

In scenarios where the reference is specified manually, e.g. for black-box functions or Stan models, more care is needed. In such cases, one alternative is to use [variational PT](@ref variational-pt) in which case the built-in variational distribution is constructed so that its normalization constant is one. 

!!! note "Normalization of Stan models"

    `BridgeStan` offers an option `propto` to skip constants 
    that do not depend on the sampled parameters. Every calls 
    to `BridgeStan` made by Pigeons disable this option to make 
    it easier to design reference distributions with a known 
    normalization constant. 