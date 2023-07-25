```@meta
CurrentModule = Pigeons
```

# [Turing.jl model as input to pigeons](@id input-turing)

To target the posterior distribution specified by 
a [Turing.jl](https://github.com/TuringLang/Turing.jl) model use 
a [`TuringLogPotential`](@ref):

```@example turing
using Pigeons, Distributions, DistributionsAD, DynamicPPL

DynamicPPL.@model function my_turing_model(n_trials, n_successes)
    p1 ~ Uniform(0, 1)
    p2 ~ Uniform(0, 1)
    n_successes ~ Binomial(n_trials, p1*p2)
    return n_successes
end

pt = pigeons(target = TuringLogPotential(my_turing_model(100, 50)));
nothing # hide
```

At the moment, only Turing models with fixed dimensionality are supported.
Both real and integer-valued random variables are supported. 
For a [`TuringLogPotential`](@ref), the [`default_explorer()`](@ref) is the [`SliceSampler`](@ref) and the [`default_reference()`](@ref) is the 
prior distribution encoded in the Turing model. 


## Manipulating the output

Internally, Turing target's states (of type `DynamicPPL.TypedVarInfo`) are stored in an unconstrained 
parameterization provided by Turing 
(for example, bounded support variables are mapped to the full real line). 
However, sample post-processing functions such as [`sample_array()`](@ref) and [`process_sample()`](@ref) 
convert back to the original ("constrained") parameterization via [`extract_sample()`](@ref). 

As a result parameterization issues can be essentially ignored when post-processing, for example some 
common post-processing are shown below, see [the section on output processing for more information](@ref output-overview). 

```@example turing
using MCMCChains
using StatsPlots
plotlyjs()

pt = pigeons(
        target = TuringLogPotential(my_turing_model(100, 50)), 
        record = [traces])
samples = Chains(sample_array(pt), variable_names(pt))
my_plot = StatsPlots.plot(samples)
StatsPlots.savefig(my_plot, "turing_posterior_densities_and_traces.html"); 

samples
```

```@raw html
<iframe src="../turing_posterior_densities_and_traces.html" style="height:500px;width:100%;"></iframe>
```

