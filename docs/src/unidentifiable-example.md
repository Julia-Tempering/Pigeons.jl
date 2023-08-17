```@meta
CurrentModule = Pigeons
```

# [Why PT? An example.](@id unidentifiable-example)

Consider a Bayesian model where the likelihood is a binomial distribution with probability parameter ``p``. 
Let us consider an over-parameterized model where we 
write ``p = p_1 p_2``. Assume that each ``p_i`` has a uniform prior on the interval ``[0, 1]``.
This is a toy example of an unidentifiable parameterization.
In practice many popular 
Bayesian models are unidentifiable. 

When there are many observations, the posterior of 
unidentifiable models concentrate on a sub-manifold, 
making sampling difficult, as shown in the [following pair plots](@ref output-plotting):
 
```@raw html
<iframe src="../pair_plot.svg" style="height:500px;width:100%;"></iframe>
```

## Unidentifiable example without PT

Let us look at trace plots obtained from performing 
single-chain MCMC on this problem. 
The key part of the code below is the argument 
`n_chains = 1`: we have designed our PT implementation 
so that setting the number of chains to one reduces to a 
standard MCMC algorithm. 

```@example why
using Pigeons
using MCMCChains
using StatsPlots
plotlyjs()

# The model described above implemented in Turing
# note we are using a large observation size here
an_unidentifiable_model = Pigeons.toy_turing_unid_target(100000, 50000)

pt = pigeons(
        target = an_unidentifiable_model, 
        n_chains = 1, # <- corresponds to single chain MCMC
        record = [traces])

# collect the statistics and convert to MCMCChains' Chains
samples = Chains(sample_array(pt), variable_names(pt))
# create the trace plots
my_plot = StatsPlots.plot(samples)
StatsPlots.savefig(my_plot, "no_pt_posterior_densities_and_traces.html"); 
nothing # hide
```

```@raw html
<iframe src="../no_pt_posterior_densities_and_traces.html" style="height:500px;width:100%;"></iframe>
```

It is quite obvious that mixing is poor, as confirmed by effective sample size (ESS) estimates:

```@example why
samples
```


## Unidentifiable example with PT

Let us enable parallel tempering now, by setting 
`n_chains` to a value greater than one:

```@example why
pt = pigeons(
        target = an_unidentifiable_model, 
        n_chains = 10, 
        record = [traces, round_trip])

# collect the statistics and convert to MCMCChains' Chains
samples = Chains(sample_array(pt), variable_names(pt))
# create the trace plots
my_plot = StatsPlots.plot(samples)
StatsPlots.savefig(my_plot, "with_pt_posterior_densities_and_traces.html"); 
nothing # hide
```

```@raw html
<iframe src="../with_pt_posterior_densities_and_traces.html" style="height:500px;width:100%;"></iframe>
```

There is a marked difference. 
Thanks to round trips through the reference distribution, 
where we can sample iid, we are able to jump at different 
parts of the state space. 

This is also confirmed by the PT ESS estimates:

```@example why
samples
```