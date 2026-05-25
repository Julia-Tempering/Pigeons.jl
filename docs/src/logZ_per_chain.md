```@meta
CurrentModule = Pigeons
```

# [Log Ratio of Normalizing Constant Across the Tempering Ladder](@id logZ-per-chain-page)

## Background

The standard [`stepping_stone()`](@ref) estimator computes a single 
number: ``\log(Z_1/Z_0)``, the log-ratio of the normalizing constants 
of the target and reference. 

However, the stepping stone estimator is built from a **telescoping product**:
 
```math
\log \frac{Z_1}{Z_0} = \sum_{k=0}^{K-1} \log \frac{Z_{\beta_{k+1}}}{Z_{\beta_k}}
```
 
where ``\beta_0 = 0, \beta_1, \ldots, \beta_K = 1`` is the temperature schedule.
 
By computing *partial sums* of this telescoping decomposition, we can 
estimate ``\log(Z_{\beta_k}/Z_0)`` for every distribution in the 
tempering ladder, not just the final target.

## Computing per-chain estimated log-ratio of the normalizing constants

Use [`stepping_stone_per_chain()`](@ref) to obtain the estimated 
``\log(Z_{\beta_k}/Z_0)`` at each temperature:

```@example perchain
using Pigeons
using Plots
plotlyjs()
 
pt = pigeons(
    target = toy_mvn_target(2), 
    n_rounds = 10,
    n_chains = 15)
 
result = stepping_stone_per_chain(pt)
nothing # hide
```

The returned `result` is a `NamedTuple` with two fields:
 
- `result.betas`: the temperature schedule (from 0 to 1)
- `result.log_norm_constants`: the cumulative ``\log(Z_{\beta_k}/Z_0)`` estimates
```@example perchain
result.betas
```
 
```@example perchain
result.log_norm_constants
```

## Plotting
 
The result can be plotted directly using the built-in `Plots.jl` recipe:
 
```@example perchain
myplot = plot(result)
savefig(myplot, "logz_per_chain_plot.html"); 
nothing # hide
```
 
```@raw html
<iframe src="../logz_per_chain_plot.html" style="height:500px;width:100%;"></iframe>
```

## Validation against analytic results
 
When both the target and reference are multivariate normals with 
kernels ``\exp(-x^\top x / (2\sigma^2))``, the log-normalizing 
constant ratio has a closed-form expression:
 
```math
\log \frac{Z_{\beta}}{Z_0} = -\frac{d}{2}\left[\log(\sigma_{\text{ref}}^2) + \log\left(\frac{\beta}{\sigma_{\text{target}}^2} + \frac{1-\beta}{\sigma_{\text{ref}}^2}\right)\right]
```
 
This can be used to verify the estimator:
 
```@example perchain
d = 5
var_ref = 25.0
var_target = 1.0
 
struct LogMVN
    var::Float64
end
 
(m::LogMVN)(x) = -(x' * x) / (2 * m.var)
 
Pigeons.initialization(mvn::LogMVN, rng, dim) = randn(rng, d)
 
pt_test = pigeons(
    target = LogMVN(var_target),
    reference = LogMVN(var_ref),
    n_rounds = 10,
    n_chains = 30)
 
result_test = stepping_stone_per_chain(pt_test)
 
analytic = [
    -(d/2) * (log(var_ref) + log(β/var_target + (1-β)/var_ref)) 
    for β in result_test.betas
]
 
myplot = plot(result_test.betas, result_test.log_norm_constants, 
    label="Stepping stone", linewidth=2)
plot!(result_test.betas, analytic, 
    label="Analytic", linestyle=:dash, linewidth=2)
xlabel!("β")
ylabel!("log(Z_β / Z₀)")
savefig(myplot, "logz_validation_plot.html"); 
nothing # hide
```
 
```@raw html
<iframe src="../logz_validation_plot.html" style="height:500px;width:100%;"></iframe>
```
