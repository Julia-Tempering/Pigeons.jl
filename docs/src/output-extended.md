```@meta
CurrentModule = Pigeons
```

# [Extended output (i.e., for all chains)](@id output-extended)

So far when outputting traces (either to memory via [`traces`](@ref) or to disk via [`disk`](@ref)), 
we have been storing only the target distribution's samples. 
This is the most common scenario and the default. 
Here we show how to instead store the samples from all chains. 

This can be useful in scenarios where all distributions $$\pi_i$$ are of interest, e.g. 
in certain statistical mechanics applications and for Bayesian inference under model 
mis-specification. 

The key argument to add is `extended_traces = true`, which we demonstrate for 
various common scenarios below.


## Posterior densities and trace plots for all chains

Make sure to have the third party `DynamicPPL`, `MCMCChains`, and `StatsPlots`
packages installed via 

```
using Pkg; Pkg.add("DynamicPPL", "MCMCChains", "StatsPlots")
```

Then use the following:

```@example
using DynamicPPL
using Pigeons
using MCMCChains
using StatsPlots
plotlyjs()

# example target: Binomial likelihood with parameter p = p1 * p2
an_unidentifiable_model = Pigeons.toy_turing_unid_target(100, 50)

pt = pigeons(target = an_unidentifiable_model, 
                n_rounds = 12,
                extended_traces = true, 
                # make sure to record the trace:
                record = [traces; round_trip; record_default()])

# collect the statistics and convert to MCMCChains' Chains
# to have axes labels matching variable names in Turing and Stan
samples = Chains(pt)

# create the trace plots
my_plot = StatsPlots.plot(samples)
StatsPlots.savefig(my_plot, "posterior_densities_and_traces_extended.html"); 
nothing # hide
```

Here the ten different colours correspond to the 10 chains interpolating between 
the posterior and the prior (here a uniform distribution).

```@raw html
<iframe src="../posterior_densities_and_traces_extended.html" style="height:500px;width:100%;"></iframe>
```


## Off-memory processing for all chains 

The same option, `extended_traces = true` can 
be used in the same fashion to save to disk 
samples from all chains:

```@example 
using Pigeons

# example target: a 1000 dimensional target
high_d_target = Pigeons.toy_mvn_target(1000)

pt = pigeons(target = high_d_target, 
                checkpoint = true,
                extended_traces = true,
                record = [disk])

first_dim_of_each = zeros(10, 1024)
process_sample(pt) do chain, scan, sample # ordered as if we had an inner loop over scans
    # each sample here is a Vector{Float64} of length 1000 
    # in general, it will is produced by extract_sample()
    first_dim_of_each[chain, scan] = sample[1]
end
```

## Accessing the annealing parameters

To obtain the annealing parameter used to define each intermediate distribution, use:

```@example schedule
using Pigeons

an_unidentifiable_model = Pigeons.toy_turing_unid_target(100, 50)

pt = pigeons(target = an_unidentifiable_model)

pt.shared.tempering.schedule
```
