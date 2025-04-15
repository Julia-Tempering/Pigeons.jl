```@meta
CurrentModule = Pigeons
```

# [Turing.jl model as input to pigeons](@id input-turing)

To target the posterior distribution specified by 
a [Turing.jl](https://github.com/TuringLang/Turing.jl) model first load `Turing`
or `DynamicPPL` and use [`TuringLogPotential`](@ref):

```@example turing
using DynamicPPL, Pigeons, Distributions

DynamicPPL.@model function my_turing_model(n_trials, n_successes)
    p1 ~ Uniform(0, 1)
    p2 ~ Uniform(0, 1)
    n_successes ~ Binomial(n_trials, p1*p2)
    return n_successes
end

my_turing_target = TuringLogPotential(my_turing_model(100, 50))
pt = pigeons(target = my_turing_target);
nothing # hide
```

At the moment, only Turing models with fixed dimensionality are supported.
Both real and integer-valued random variables are supported. 
For a [`TuringLogPotential`](@ref), the [`default_explorer()`](@ref) is the [`SliceSampler`](@ref) and the [`default_reference()`](@ref) is the 
prior distribution encoded in the Turing model. 

## Gradient-based sampling with [`AutoMALA`](@ref)

For Turing models with fully continuous state-spaces—as is the case for
`my_turing_model` defined above—[`AutoMALA`](@ref) can be an effective alternative to
[`SliceSampler`](@ref)—especially for high-dimensional problems. Because Turing targets
conform to the [LogDensityProblemsAD.jl](https://github.com/tpapp/LogDensityProblemsAD.jl) 
interface, Automatic Differentiation (AD) backends can be used to obtain the gradients
needed by [`AutoMALA`](@ref).

The default AD backend for [`AutoMALA`](@ref) is [ForwardDiff](https://juliadiff.org/ForwardDiff.jl/).
However, Turing supports other backends that may exhibit improved performance. 
One such is [Mooncake](https://compintell.github.io/Mooncake.jl/stable/), which 
we can use in Pigeons via

```@example turing
using ADTypes, Mooncake
pt = pigeons(
    target = my_turing_target,
    explorer = AutoMALA(default_autodiff_backend = AutoMooncake(nothing))
);
nothing # hide
```

Alternatively, in the special case when the Turing model does not involve branching 
decisions (`if`, `while`, etc...) depending on latent variables, 
[ReverseDiff](https://github.com/JuliaDiff/ReverseDiff.jl)
with compiled tape may provide accelerated performance. Since `my_turing_target` satisfies
this criterion, we can use [`AutoMALA`](@ref) with the ReverseDiff AD backend via

```@example turing
using ADTypes, ReverseDiff
pt = pigeons(
    target = my_turing_target,
    explorer = AutoMALA(default_autodiff_backend = AutoReverseDiff(compile=true))
);
nothing # hide
```

## Using DynamicPPL.@addlogprob!

The macro `DynamicPPL.@addlogprob!` is sometimes used when additional flexibility is needed while incrementing the log probability. To do so with Pigeons.jl, you will need to enclose the call to `DynamicPPL.@addlogprob!` within an if statement as shown below. Failing to do so will lead to invalid results.

```julia 
DynamicPPL.@model function my_turing_model(my_data)
    # code here
    if DynamicPPL.leafcontext(__context__) !== DynamicPPL.PriorContext() 
        DynamicPPL.@addlogprob! logpdf(MyDist(parms), my_data)
    end
end
```

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

pt = pigeons(target = my_turing_target, record = [traces])
samples = Chains(pt)
my_plot = StatsPlots.plot(samples)
StatsPlots.savefig(my_plot, "turing_posterior_densities_and_traces.html"); 

samples
```

```@raw html
<iframe src="../turing_posterior_densities_and_traces.html" style="height:500px;width:100%;"></iframe>
```

## Custom initialization

It is sometimes useful to provide a custom initialization, for example to start in a feasible region. 
This can be done as follows:

```@example custom_init
using DynamicPPL, Pigeons, Distributions, Random

DynamicPPL.@model function toy_beta_binom_model(n_trials, n_successes)
    p ~ Uniform(0, 1)
    n_successes ~ Binomial(n_trials, p)
    return n_successes
end

function toy_beta_binom_target(n_trials = 10, n_successes = 2)
    return Pigeons.TuringLogPotential(toy_beta_binom_model(n_trials, n_successes))
end

const ToyBetaBinomType = typeof(toy_beta_binom_target())

function Pigeons.initialization(target::ToyBetaBinomType, rng::AbstractRNG, ::Int64) 
    result = DynamicPPL.VarInfo(rng, target.model, DynamicPPL.SampleFromPrior(), DynamicPPL.PriorContext())
    result = DynamicPPL.link(result, target.model)

    # custom init goes here: for example here setting the variable p to 0.5
    Pigeons.update_state!(result, :p, 1, 0.5)

    return result
end

pt = pigeons(target = toy_beta_binom_target(), n_rounds = 0)
@assert Pigeons.variable(pt.replicas[1].state, :p) == [0.5]
```

