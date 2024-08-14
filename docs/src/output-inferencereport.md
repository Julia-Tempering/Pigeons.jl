# [Automated reports](@id output-inferencereport)

[InferenceReport](https://github.com/Julia-Tempering/InferenceReport.jl) is a Julia package to automatically generate a web page or PDF report from  
Pigeons' output, containing common plots and diagnostics. 

We provide a brief summary on how to use InfereReport here, see 
the [full InferenceReport documentation](https://julia-tempering.github.io/InferenceReport.jl/stable/) for details. 

## Install InferenceReport

```
using Pkg; Pkg.add("InferenceReport")
```

## Basic usage 

```@example inferencereport 
using InferenceReport
using Pigeons 

pt = pigeons(
        target = toy_mvn_target(2), 
        n_rounds = 4,
        record = [traces; round_trip; record_default()])

report(pt) 
nothing # hide
```

This will generate an HTML report with various useful diagnostic 
plots and open it in your default browser. 

[Examples available here.](https://julia-tempering.github.io/InferenceReport.jl/stable/generated/toy_turing_unid_model/src/)

