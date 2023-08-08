```@meta
CurrentModule = Pigeons
```

# [Numerical outputs and diagnostics](@id output-numerical)

Use [`sample_array()`](@ref) to convert target chain 
samples into a format that can then be consumed by the 
third party package 
[MCMCChains.jl](https://github.com/TuringLang/MCMCChains.jl). 
We outline some useful features here, read  
[the MCMCChains.jl documentation](https://github.com/TuringLang/MCMCChains.jl) for more information.


## Quick summary of ESS, moments, etc

Make sure to have the third party package `MCMCChains`  installed via 

```
using Pkg; Pkg.add("MCMCChains")
```

Also make sure to record the trace, with `record = [traces]`:

```@example numerical
using Pigeons
using MCMCChains

# example target: Binomial likelihood with parameter p = p1 * p2
an_unidentifiable_model = Pigeons.toy_turing_unid_target(100, 50)

pt = pigeons(
        target = an_unidentifiable_model, 
        record = [traces; round_trip; record_default()]
    )

# collect the statistics and convert to MCMCChains' Chains
# to have axes labels matching variable names in Turing and Stan
samples = Chains(sample_array(pt), variable_names(pt))

samples
```

## Accessing individual diagnostics and summaries

Computing a mean 
(but see [online statistics](@ref output-online) for 
a constant memory alternative):

```@example numerical
using Statistics 
m = mean(samples)
```

to access an individual entry in this example and the following ones:

```@example numerical
m[:p1, :mean]
```

Highest posterior density interval:

```@example numerical
hpd(samples, alpha = 0.05)
```

For ESS estimates:

```@example numerical
ess(samples)
```