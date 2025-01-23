```@meta
CurrentModule = Pigeons
```

# [Plotting](@id output-plotting)

Use [`sample_array()`](@ref) to convert target chain 
samples into a format that can then be consumed by 
third party plotting packages such as 
[MCMCChains.jl](https://github.com/TuringLang/MCMCChains.jl) 
and [PairPlots.jl](https://sefffal.github.io/PairPlots.jl/).

See below for examples of posterior densities and trace plots.


## Posterior densities and trace plots

Make sure to have the third party `DynamicPPL`, `MCMCChains`, and `StatsPlots`
packages installed via

```
using Pkg; Pkg.add("DynamicPPL", "MCMCChains", "StatsPlots")
```

Then use the following:

```@example traces
using DynamicPPL
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
samples = Chains(sample_array(pt), sample_names(pt))

# since the above line is frequently needed, Pigeons includes 
# an MCMCChains extension allowinging you to use the shorter form:
samples = Chains(pt)

# create the trace plots
my_plot = StatsPlots.plot(samples)
StatsPlots.savefig(my_plot, "posterior_densities_and_traces.html"); 
nothing # hide
```

```@raw html
<iframe src="../posterior_densities_and_traces.html" style="height:500px;width:100%;"></iframe>
```

## Monitoring the log density

The value of the log density is appended to each sample. Continuing the 
above example, this can be seen 
from the variable names indexing the flattened vector created by 
[`sample_array()`](@ref):

```@example traces
sample_names(pt)
```

When using the `Chains(pt)` constructor as shown above, the 
un-normalized log density is stored inside MCMCChains' "internal" 
storage so will not appear in plots by default. To show it, use the following:

```@example traces
params, internals = MCMCChains.get_sections(samples) 

my_plot = StatsPlots.plot(internals)
StatsPlots.savefig(my_plot, "logdensity.html"); 
nothing # hide
```

```@raw html
<iframe src="../logdensity.html" style="height:500px;width:100%;"></iframe>
```

## Posterior pair plots

!!! note

    The code snippet in this section only works with Julia 1.9. 
    See https://sefffal.github.io/PairPlots.jl/dev/chains/ for a workaround.

Make sure to have the third party packages `DynamicPPL`, `MCMCChains`, `CairoMakie`, and `PairPlots`
installed via 

```
using Pkg; Pkg.add("DynamicPPL", "MCMCChains", "CairoMakie", "PairPlots")
```

```
using DynamicPPL
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

samples = Chains(pt)
# Warning: the line below only works for Julia 1.9
#          see https://sefffal.github.io/PairPlots.jl/dev/chains/ for a workaround
my_plot = PairPlots.pairplot(samples) 

CairoMakie.save("pair_plot.svg", my_plot)
nothing # hide
```

```@raw html
<iframe src="../pair_plot.svg" style="height:500px;width:100%;"></iframe>
```