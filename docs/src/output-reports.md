```@meta
CurrentModule = Pigeons
```

# [Interpreting pigeons' standard output](@id output-reports)

During the execution of parallel tempering, interim diagnostics 
can be computed and printed to standard out at the end of every iteration (this can be disabled using `show_report = false`):

```@example reports
using Pigeons

pigeons(target = toy_mvn_target(100))
nothing # hide
```

The functions called to emit each of these can 
be found at [`all_reports()`](@ref). Some key quantities:

- `Λ`: the global communication barrier, as described in [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464) and estimated using the sum of rejection estimator analyzed in the same reference. Syed et al., 2021 also developed a rule of thumb to configure the number of chains: PT should be set to roughly 2Λ. 
- `time` and `allc`: the time (in second) and allocation (in bytes) used in each round. 
- `log(Z₁/Z₀)`: the [`stepping_stone()`](@ref) estimator for the log of the normalization constant, see [the documentation page on approximation of the normalization constant](@ref output-normalization). 
- `min(α)` and `mean(α)`: minimum and average swap acceptance rates over the PT chains. 

Additional statistics can be shown when more [recorders](@ref collecting-statistics) 
are added. For example, to accumulate other constant-memory summary statistics:

```@example reports
pigeons(target = toy_mvn_target(100), record = record_online(), explorer = AutoMALA())
nothing # hide
```

- `max|ρ|` and `mean|ρ|`: maximum and average (across chains) correlation of the random variables ``L^t_i = V(X_i)`` and ``L^{t+1}_i = V(X_i)`` where ``V = \log \pi_N / \pi_1``, ``X_i \sim \pi_{\beta_i}``, and ``t, t+1`` are indices just before and after a call to [`step!()`](@ref). 
- `min(αₑ)` and `mean(αₑ)`: minimum and average (across chains) of the explorer's acceptance rates. 


## Programmatic access

The tables described above can also be accessed as a `DataFrame` via:

```@example prog
using Pigeons
pt = pigeons(target = toy_mvn_target(100))
pt.shared.reports.summary
```

Detailed statistics can be accessed via these DataFrames. 
For example 
to obtain mean swap acceptance probabilities for each round and 
pair of communicating chains, use:

```@example prog
first(pt.shared.reports.swap_prs, 20)
```

Creating a plot from this:

```@example prog
using StatsPlots
plotlyjs()
my_plot =  @df pt.shared.reports.swap_prs StatsPlots.plot(:round, :mean, group = :first)
StatsPlots.savefig(my_plot, "swap_prs.html"); 
nothing # hide
```

```@raw html
<iframe src="../swap_prs.html" style="height:500px;width:100%;"></iframe>
```