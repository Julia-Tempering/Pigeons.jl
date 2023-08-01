```@meta
CurrentModule = Pigeons
```

# [Online (constant memory) statistics](@id output-online)

When the dimensionality of a model is large and/or the 
number of MCMC samples is large, the samples may not 
fit in memory. 
The most flexible way to deal with this situation is 
to write samples to disk and process them one at the time, 
as described in [the off-memory processing documentation](@ref output-off-memory). 
However, certain statistics can be computed using fixed 
dimensional sufficient statistics yielding more 
efficient algorithms. We describe this alternative here. 


## Built-in online statistics: mean and variance 

Simply include the [`online()`](@ref) recorder to get 
access to constant memory computation of the mean and variance.  

```@example online
using Pigeons

# example target: Binomial likelihood with parameter p = p1 * p2
an_unidentifiable_model = Pigeons.toy_turing_unid_target(100, 50)

pt = pigeons(
        target = an_unidentifiable_model, 
        record = [online]
    )

using Statistics 
mean(pt)
```


## Adding other online statistics

The computation of online statistics makes use of 
[OnlineStats.jl](https://joshday.github.io/OnlineStats.jl/latest/). 

The functions `mean` and `var` are implemented via the 
types `Mean` and `Variance` from the 
OnlineStats library. 
Many other constant-memory statistic accumulators [are available in the OnlineStats library](https://joshday.github.io/OnlineStats.jl/latest/stats_and_models/). 
To add additional constant-memory statistic accumulators, 
register them via [`register_online_type()`](@ref). 
Here is an example to add computation of extrema:

```@example online
using OnlineStats

# register a type <: OnlineStat to be included
Pigeons.register_online_type(Extrema)

pt = pigeons(
        target = an_unidentifiable_model, 
        record = [online]
    )

Pigeons.get_statistic(pt, :singleton_variable, Extrema)
```