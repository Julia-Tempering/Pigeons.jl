```@meta
CurrentModule = Pigeons
```

# [Custom explorers](@id input-explorers)

Pigeons have several built-in [`explorer`](@ref) kernels such as 
[`AutoMALA`](@ref) and a [`SliceSampler`](@ref). 
However when the state space is neither the reals nor the integers, 
or for performance reasons, it may be necessary to create custom 
exploration MCMC kernels. 

```@setup explorer
using Pigeons 
using Random
using StatsFuns

struct MyLogPotential 
    n_trials::Int
    n_successes::Int
end

function (log_potential::MyLogPotential)(x) 
    p1, p2 = x
    if !(0 < p1 < 1) || !(0 < p2 < 1)
        return -Inf64 
    end
    p = p1 * p2
    return StatsFuns.binomlogpdf(log_potential.n_trials, p, log_potential.n_successes)
end

Pigeons.initialization(::MyLogPotential, ::AbstractRNG, ::Int) = [0.5, 0.5]
```


## Creating a new explorer

We show how to create a new explorer, 
for pedagogy, a simple [independence Metropolis algorithm](https://bookdown.org/rdpeng/advstatcomp/metropolis-hastings.html#independence-metropolis-algorithm), applied to 
our familiar [unidentifiable toy example](@ref unidentifiable-example), 
based on [Julia black-box implementation](@ref input-julia). 

```@example explorer
struct MyIndependenceSampler 
    which_parameter_index::Int
end
function Pigeons.step!(explorer::MyIndependenceSampler, replica, shared)
    state = replica.state 
    rng = replica.rng 
    i = explorer.which_parameter_index
    # Note: the log_potential is an InterpolatedLogPotential between the target and reference
    log_potential = Pigeons.find_log_potential(replica, shared.tempering, shared)
    log_pr_before = log_potential(state)
    # propose
    state_before = state[i]
    state[i] = rand(rng) 
    log_pr_after = log_potential(state)
    # accept-reject step 
    accept_ratio = exp(log_pr_after - log_pr_before) 
    if accept_ratio < 1 && rand(rng) > accept_ratio 
        # reject: revert the move we just proposed
        state[i] = state_before
    end # (nothing to do if accept, we work in-place)
end
```

## Creating combinations of explorers

To alternate between two explorers, use [`Compose`](@ref): for example continuing on 
our example, we want to alternate between sampling the two parameters of our model:

```@example explorer
pt = pigeons(
        target = MyLogPotential(100, 50), 
        reference = MyLogPotential(0, 0),
        explorer = Compose(MyIndependenceSampler(1), MyIndependenceSampler(2))
    )
nothing # hide
```

## Adaptation

We assume the following model for MCMC explorer adaptation: 

1. during each PT round, statistics are collected distributively, 
2. at the end of each round, the statistics are reduced and shared, and the explorers are given an opportunity to update based on these statistics. 

To control (1), use [`explorer_recorder_builders`](@ref). 
For example, [AutoMALA requests online statistics to be computed on 
uncontrainted parameters to perform pre-conditioning](https://github.com/Julia-Tempering/Pigeons.jl/blob/8cb8d5ad5e2ad3f5dea26e6d68f494c8b6cdc7c6/src/explorers/AutoMALA.jl#L308). 
By default, [`explorer_recorder_builders`](@ref) returns an empty list. 

To control (2), use [`adapt_explorer`](@ref) which is fed the 
reduced statistics. By default, [`adapt_explorer`](@ref) is a no-op. 