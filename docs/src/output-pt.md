```@meta
CurrentModule = Pigeons
```

# [Parallel Tempering-specific diagnostics](@id output-pt)

We describe how to produce some key 
non-reversible parallel tempering diagnostics 
described in [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464). 

## Global communication barrier

The global communication barrier can be used 
to set the number of chains. 
The theoretical framework of Syed et al., 2021  
yields that under simplifying assumptions, it is optimal to set the number of chains 
(the argument `n_chains` in [`Inputs`](@ref) or  `pigeons()`) to roughly 2Λ.

The global communication barrier is shown 
at each round and can also be accessed via 
[`global_barrier()`](@ref).

```@example pt
using Pigeons

pt = pigeons(target = Pigeons.toy_turing_unid_target(100, 50))
Pigeons.global_barrier(pt)
```

When both a fixed and variational are used, they are printed separately, 
labelled Λ and Λ_var for the fixed and variational global barriers 
respectively:

```@example pt
using Pigeons

pt = pigeons(target = Pigeons.toy_turing_unid_target(100, 50), 
                variational = GaussianReference(),
                n_chains_variational = 10)
nothing # hide
```

## Round trips and tempered restarts

A tempered restart happens when a sample from the reference 
percolates to the target. 
When the reference supports iid sampling, tempered restarts 
can enable large jumps in the state space. 

A round-trip happens when we have a full cycle from 
reference to target and back to reference. 

To count tempered restarts and round trips, 
add the [`round_trip()`](@ref) recorder:

```@example pt
pt = pigeons(target = Pigeons.toy_turing_unid_target(100, 50), 
           record = [round_trip; record_default()])
nothing # hide
```

The values can also be accessed as follows:

```@example pt
Pigeons.n_tempered_restarts(pt), Pigeons.n_round_trips(pt)
```


## Local communication barrier

When the global communication barrier is large, 
many chains may be required to obtain tempered restarts. 

The local communication barrier can be used to 
visualize the cause of a high global communication barrier. 
For example, if there is a sharp peak close to a 
reference constructed from the prior, it may be 
useful to switch to a [variational approximation](@ref variational-pt).

The local barrier can be plotted as follows:

```@example pt
using Plots 
plotlyjs()
myplot = plot(pt.shared.tempering.communication_barriers.localbarrier);
savefig(myplot, "local_barrier_plot.html"); 
nothing # hide
```

```@raw html
<iframe src="../local_barrier_plot.html" style="height:500px;width:100%;"></iframe>
```


## Index process

The index process tracks the permutation of chains as machine exchange 
annealing parameters. Each row is a chain and each connected line corresponds
to a replica. To enable this we use the [`index_process`](@ref) recorder:

```@example pt
pt = pigeons(
        target = toy_mvn_target(1), 
        record = [index_process], 
        n_rounds = 5)
myplot = plot(pt.reduced_recorders.index_process)
savefig(myplot, "index_process_plot.html"); 
nothing # hide
```

```@raw html
<iframe src="../index_process_plot.html" style="height:500px;width:100%;"></iframe>
```