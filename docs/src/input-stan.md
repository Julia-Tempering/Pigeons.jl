```@meta
CurrentModule = Pigeons
```

# Stan model as input to pigeons

!!! note

    We use the package `BridgeStan.jl` which will attempt 
    to automatically install Stan. 
    For `BridgeStan.jl` to work, a C++ compiler and 
    `make` are needed, see 
    [the BridgeStan requirements](https://roualdes.github.io/bridgestan/latest/getting-started.html#requirement-c-toolchain).


To target the posterior distribution specified by 
a [Stan](https://mc-stan.org/) model, use 
a [`StanLogPotential`](@ref). 

Here we show how this is done using our familiar [unidentifiable toy example](unidentifiable-example.html)
[ported to the Stan language](https://github.com/Julia-Tempering/Pigeons.jl/blob/main/examples/stan/unid.stan).

```@example stan
using Pigeons 
using Random

# We will use this type to make sure our iid sampler (next section) will 
# be used only for this model
struct StanUnidentifiableExample end

function stan_unid(n_trials, n_successes)
    # path to a .stan file (compiled files will be cached in the same directory)
    stan_file = dirname(dirname(pathof(Pigeons))) * "/examples/stan/unid.stan"

    # data can be specified either using...
    #   - a path to a json file with suffix .json containing the data to condition on
    #   - the JSON string itself (here via the utility Pigeons.json())
    stan_data = Pigeons.json(; n_trials, n_successes)

    return StanLogPotential(stan_file, stan_data, StanUnidentifiableExample())
end

pt = pigeons(target = stan_unid(100, 50), reference = stan_unid(0, 0))
nothing #hide
```

Notice that we have specified a reference distribution, in this case the same model but with 
no observations (hence the prior). This needs to be done with Stan targets because it is 
not possible to automatically extract a prior from a .stan file. 

For a [`StanLogPotential`](@ref), the [`default_explorer()`](@ref) is [`AutoMALA`](@ref). 


## Sampling from the reference distribution

```@example stan
using BridgeStan

function Pigeons.sample_iid!(
        log_potential::StanLogPotential{M, S, D, StanUnidentifiableExample}, replica, shared) where {M, S, D}
    # sample in constrained space
    state = replica.state.unconstrained_parameters
    rng = replica.rng 
    constrained = rand(rng, 2)
    # transform to unconstrained space
    replica.state.unconstrained_parameters .= BridgeStan.param_unconstrain(log_potential.model, constrained)
end

pt = pigeons(target = stan_unid(100, 50), reference = stan_unid(0, 0))
nothing # hide
```