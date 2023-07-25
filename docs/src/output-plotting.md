```@meta
CurrentModule = Pigeons
```

# [Plotting](@id output-plotting)

Use [`sample_array()`](@ref) to convert target chain 
samples into a format that can then be consumed by 
third party packages such as 
[MCMCChains.jl](https://github.com/TuringLang/MCMCChains.jl) 
and [PairPlots.jl](https://sefffal.github.io/PairPlots.jl/).

See below for examples of posterior densities and trace plots.


## Posterior densities and trace plots

Make sure to have the third party `MCMCChains` and `StatsPlots`
packages installed via 

```
using Pkg; Pkg.add("MCMCChains", "StatsPlots")
```

Then use the following:

```@example traces
using Pigeons
using MCMCChains
using StatsPlots
plotlyjs()

# example target: Binomial likelihood with parameter p = p1 * p2
an_unidentifiable_model = Pigeons.toy_turing_unid_target(100, 50)

pt = pigeons(target = an_unidentifiable_model, 
                n_rounds = 12,
                # make sure to record the trace:
                record = [traces; round_trip; record_default()])

# collect the statistics and convert to MCMCChains' Chains
# to have axes labels matching variable names in Turing and Stan
samples = Chains(sample_array(pt), variable_names(pt))

# create the trace plots
my_plot = StatsPlots.plot(samples)
StatsPlots.savefig(my_plot, "posterior_densities_and_traces.html"); 
nothing # hide
```

```@raw html
<iframe src="../posterior_densities_and_traces.html" style="height:500px;width:100%;"></iframe>
```

## Posterior pair plots

!!! note

    The code snippet in this section only works with Julia 1.9. 
    See https://sefffal.github.io/PairPlots.jl/dev/chains/ for a workaround.

Make sure to have the third party packages `MCMCChains`, `CairoMakie` and `PairPlots`
installed via 

```
using Pkg; Pkg.add("MCMCChains", "CairoMakie", "PairPlots")
```

```
using Pigeons
using MCMCChains
using CairoMakie
using PairPlots

# same examples as last section
an_unidentifiable_model = Pigeons.toy_turing_unid_target(100, 50)

pt = pigeons(target = an_unidentifiable_model, 
                n_rounds = 12,
                # make sure to record the trace:
                record = [traces; round_trip; record_default()])

samples = Chains(sample_array(pt), variable_names(pt))
# Warning: the line below only works for Julia 1.9
#          see https://sefffal.github.io/PairPlots.jl/dev/chains/ for a workaround
my_plot = PairPlots.pairplot(samples) 

CairoMakie.save("pair_plot.svg", my_plot)
nothing # hide
```
