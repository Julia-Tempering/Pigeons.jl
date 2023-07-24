```@meta
CurrentModule = Pigeons
```

# Julia code as input to pigeons

In typical Bayesian statistics applications, it is 
easiest to specify the model in a modelling language, 
such as Turing, but sometimes to get more flexibility or 
speed it is useful to implement the density evaluation 
manually as a "black-box" Julia function. 

Here we show how this is done using our familiar [unidentifiable toy example][unidentifiable-example.html]
[ported to the Stan language](https://github.com/Julia-Tempering/Pigeons.jl/blob/main/examples/stan/unid.stan).

We first create a custom type, `UnidToyLogPotential` to control dispatch on the interface [`target`](@ref).


```@example julia
using Pigeons 
using Random
using StatsFuns

struct UnidToyLogPotential 
    n_trials::Int
    n_successes::Int
end
```

Next, we make `UnidToyLogPotential` a 
[function-like object](https://docs.julialang.org/en/v1/manual/methods/#Function-like-objects), so that e.g.
`my_log_potential([0.5, 0.5])` will possible and 
hence satisfy the [`log_potential`](@ref) interface:

```@example julia
function (log_potential::UnidToyLogPotential)(x) 
    p1, p2 = x
    if !(0 < p1 < 1) || !(0 < p2 < 1)
        return -Inf64 
    end
    p = p1 * p2
    return StatsFuns.binomlogpdf(log_potential.n_trials, p, log_potential.n_successes)
end

# e.g.:
my_log_potential = UnidToyLogPotential(100, 50)
my_log_potential([0.5, 0.5])
```

Next, we need to specify how to create fresh [`state`](@ref) objects: 

```@example julia
Pigeons.initialization(::UnidToyLogPotential, ::AbstractRNG, ::Int) = [0.5, 0.5]
```

We can now run the sampler:

```@example julia
pt = pigeons(
        target = UnidToyLogPotential(100, 50), 
        reference = UnidToyLogPotential(0, 0)
    )
nothing # hide
```

Notice that we have specified a reference distribution, in this case the same model but with 
no observations (hence the prior).
This needs to be done with Julia "black-box" targets because it is 
not possible to automatically extract a prior from a .stan file. 

The [`default_explorer()`](@ref) is the [`SliceSampler`](@ref). 


## Sampling from the reference distribution

Ability to sample from the reference distribution can be beneficial, e.g. to jump modes 
in multi-modal distribution. 
For black-box Julia function targets, this is done as follows:

```@example julia

function Pigeons.sample_iid!(::UnidToyLogPotential, replica, shared)
    state = replica.state 
    rng = replica.rng 
    rand!(rng, state)
end

pt = pigeons(
        target = UnidToyLogPotential(100, 50), 
        reference = UnidToyLogPotential(0, 0)
    )
nothing # hide
```


## Changing the explorer 

Here is an example using [`AutoMALA`](@ref) instead of the default 
[`SliceSampler`](@ref). We only need to add methods to make 
our custom type `UnidToyLogPotential` conform the 
[LogDensityProblems interface](https://github.com/tpapp/LogDensityProblems.jl):

```@example julia
using LogDensityProblems

LogDensityProblems.dimension(lp::UnidToyLogPotential) = 2
LogDensityProblems.logdensity(lp::UnidToyLogPotential, x) = lp(x)

pt = pigeons(
        target = UnidToyLogPotential(100, 50), 
        reference = UnidToyLogPotential(0, 0), 
        explorer = AutoMALA(default_autodiff_backend = :ForwardDiff) 
    )
nothing # hide
```


## Manipulating the output

Some 
common post-processing are shown below, see [the section on output processing for more information](output-overview
.html). 

```@example julia
using MCMCChains
using StatsPlots

pt = pigeons(
        target = UnidToyLogPotential(100, 50), 
        reference = UnidToyLogPotential(0, 0), 
        explorer = AutoMALA(default_autodiff_backend = :ForwardDiff),
        record = [traces])
samples = Chains(sample_array(pt), variable_names(pt))
my_plot = StatsPlots.plot(samples)
StatsPlots.savefig(my_plot, "julia_posterior_densities_and_traces.html"); 

samples
```

```@raw html
<iframe src="julia_posterior_densities_and_traces.html" style="height:500px;width:100%;"></iframe>
```


