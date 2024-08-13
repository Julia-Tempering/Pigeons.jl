```@meta
CurrentModule = Pigeons
```

# [Julia code as input to pigeons](@id input-julia)

In typical Bayesian statistics applications, it is 
easiest to specify the model in a modelling language, 
such as Turing, but sometimes to get more flexibility or 
speed it is useful to implement the density evaluation 
manually as a "black-box" Julia function. 

Here we show how this is done using our familiar [unidentifiable toy example](@ref unidentifiable-example).

We first create a custom type, `MyLogPotential` to control dispatch on the interface [`target`](@ref).


```@example julia
using Pigeons 
using Random
using Distributions

struct MyLogPotential 
    n_trials::Int
    n_successes::Int
end
```

Next, we make `MyLogPotential` a 
[function-like object](https://docs.julialang.org/en/v1/manual/methods/#Function-like-objects), so that we can write expressions of the form
`my_log_potential([0.5, 0.5])` and 
hence `MyLogPotential` satisfies the [`log_potential`](@ref) interface:

```@example julia
function (log_potential::MyLogPotential)(x) 
    p1, p2 = x
    if !(0 < p1 < 1) || !(0 < p2 < 1)
        return -Inf64 
    end
    p = p1 * p2
    return logpdf(Binomial(log_potential.n_trials, p), log_potential.n_successes)
end

# e.g.:
my_log_potential = MyLogPotential(100, 50)
my_log_potential([0.5, 0.5])
```

Next, we need to specify how to create fresh [`state`](@ref) objects: 

```@example julia
Pigeons.initialization(::MyLogPotential, ::AbstractRNG, ::Int) = [0.5, 0.5]
```

We can now run the sampler:

```@example julia
pt = pigeons(
        target = MyLogPotential(100, 50), 
        reference = MyLogPotential(0, 0)
    )
nothing # hide
```

Notice that we have specified a reference distribution, in this case the same model but with 
no observations (hence the prior).
Indeed, in contrast to targets specified using 
Turing.jl, it is not possible to construct a 
reference automatically from Julia "black-box" targets. 

The [`default_explorer()`](@ref) is the [`SliceSampler`](@ref). 


## Sampling from the reference distribution

Ability to sample from the reference distribution can be beneficial, e.g. to jump modes 
in multi-modal distribution. 
For black-box Julia function targets, this is done as follows:

```@example julia

function Pigeons.sample_iid!(::MyLogPotential, replica, shared)
    state = replica.state 
    rng = replica.rng 
    rand!(rng, state)
end

pt = pigeons(
        target = MyLogPotential(100, 50), 
        reference = MyLogPotential(0, 0)
    )
nothing # hide
```


## Changing the explorer 

Here is an example using [`AutoMALA`](@ref)—a gradient-based sampler—instead of the default 
[`SliceSampler`](@ref). We'll use the [Enzyme](https://enzyme.mit.edu/julia) backend, a state-of-the-art
AD system that supports targets written in plain Julia. Enzyme is considerably faster than the default
[ForwardDiff](https://juliadiff.org/ForwardDiff.jl/), whose main advantage is compatibility 
with a broader range of targets. Many other AD backends are supported by the
[LogDensityProblemsAD.jl](https://github.com/tpapp/LogDensityProblemsAD.jl) interface.

To proceed, we only need to add methods to make our custom type `MyLogPotential` conform to the 
[LogDensityProblems interface](https://github.com/tpapp/LogDensityProblems.jl):

```@example julia
using Enzyme
using LogDensityProblems

LogDensityProblems.dimension(lp::MyLogPotential) = 2
LogDensityProblems.logdensity(lp::MyLogPotential, x) = lp(x)

pt = pigeons(
        target = MyLogPotential(100, 50), 
        reference = MyLogPotential(0, 0), 
        explorer = AutoMALA(default_autodiff_backend = :Enzyme) 
    )
nothing # hide
```

Pigeons have several built-in [`explorer`](@ref) kernels such as 
[`AutoMALA`](@ref) and a [`SliceSampler`](@ref). 
However when the state space is neither the reals nor the integers, 
or for performance reasons, it may be necessary to create custom 
exploration MCMC kernels.
This is described on the [custom explorers page](@ref input-explorers).


## Manipulating the output

Some 
common post-processing are shown below, see [the section on output processing for more information](@ref output-overview). 

```@example julia
using MCMCChains
using StatsPlots
plotlyjs()

pt = pigeons(
        target = MyLogPotential(100, 50), 
        reference = MyLogPotential(0, 0), 
        explorer = AutoMALA(default_autodiff_backend = :Enzyme),
        record = [traces])
samples = Chains(pt)
my_plot = StatsPlots.plot(samples)
StatsPlots.savefig(my_plot, "julia_posterior_densities_and_traces.html"); 

samples
```

```@raw html
<iframe src="../julia_posterior_densities_and_traces.html" style="height:500px;width:100%;"></iframe>
```


