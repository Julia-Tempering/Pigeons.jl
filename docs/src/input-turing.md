```@meta
CurrentModule = Pigeons
```

# Turing.jl model as input

To target the posterior distribution specified by 
a [Turing.jl](https://turing.ml/) model use 
a [`TuringLogPotential`](@ref):

```@example 
using Pigeons, Distributions, DistributionsAD, DynamicPPL

DynamicPPL.@model function my_turing_model(number, sum)
    p1 ~ Uniform(0, 1)
    p2 ~ Uniform(0, 1)
    sum ~ Binomial(number, p1*p2)
    return sum
end

pt = pigeons(target = TuringLogPotential(my_turing_model(100, 50)));
nothing # hide
```

At the moment, only Turing models with fixed dimensionality are supported.
Both real and integer-valued random variables are supported. 
For a [`TuringLogPotential`](@ref), the [`default_explorer()`](@ref) is the [`SliceSampler`](@ref) and the [`default_reference()`](@ref) is the 
prior distribution encoded in the Turing model. 
