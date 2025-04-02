# Documentation generation

## To generate the documentation locally

From the root of the Pigeons repo:

```
$ julia
julia> include("docs/make.jl")
```

To view the generated website, use LiveServer (but don't add it to the Project file)
```julia
using LiveServer
serve(dir="docs/build")
```

If the documentation build hangs (https://github.com/Julia-Tempering/Pigeons.jl/issues/60)
a workaround is the following: 

1. start a REPL in VSCode
2. run the documentation from there

## Generating a single page

See `docs/toggle.jl`.
