# Documentation generation

## To generate the documentation locally

From the root of the Pigeons repo:

```
julia
include("docs/make.jl")
```

If the documentation build hangs (https://github.com/Julia-Tempering/Pigeons.jl/issues/60)
a workaround is the following: 

1. start a REPL in VSCode
2. run the documentation from there

## Generating a single page

See `docs/toggle.jl`.