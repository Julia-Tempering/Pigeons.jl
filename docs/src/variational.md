```@meta
CurrentModule = Pigeons
```

# [Variational PT](@id variational-pt)

We describe here the implementation 
of Variational PT, [Surjanovic et al., 2022](https://arxiv.org/abs/2206.00080) included in Pigeons. 
Both the basic variational PT and stabilized variants 
introduced in 
Surjanovic et al., 2022 are available. 


## Basic variational PT

Enable variational PT by supplier the `variational` option 
to `pigeons(...)`:

```@example variational
using Pigeons

pigeons(
    target = Pigeons.toy_turing_unid_target(100, 50), 
    variational = GaussianReference(first_tuning_round = 5))
nothing # hide
```

Note variational fitting only starts at `first_tuning_round`. 
The fixed reference is used before that point.


## Stabilized variational PT 

[Surjanovic et al., 2022](https://arxiv.org/abs/2206.00080) describes situations where the variational fitting can 
cause catastrophic forgetting of modes. 
This is remediated by using both a fixed and a variational 
reference each linked to two copies of the target, which 
are also swapped according to a non-reversible swapping 
scheme. 

Enable stabilized variational PT by adding the `n_chains_variational` option 
to `pigeons(...)`:

```@example variational
pigeons(
    target = Pigeons.toy_turing_unid_target(100, 50), 
    variational = GaussianReference(first_tuning_round = 5), 
    n_chains_variational = 10)
nothing # hide
```
