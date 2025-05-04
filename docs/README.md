# Documentation generation

## To generate the documentation locally

From the root of the Pigeons repo:

```julia-repl
$ julia --project=docs
julia> import Pkg; Pkg.instantiate()

julia> include("docs/make.jl")
```

### To preview the generated documentation

To view the generated website, use LiveServer (but don't add it to the Project file)

You can do this in one of two ways: adding it globally to your user environment
(useful if you work with a lot of documentation) or create a temporary environment:

- For adding LiveServer to your global environment, run (the second command
  needs to be run from the root of the Pigeons repo)

  ```sh
  $ julia -e 'import Pkg; Pkg.add("LiveServer")' # only needed to run once
  $ julia -e 'using LiveServer; serve(dir="docs/build")' # for starting the docs server
  ```

- For creating a temporary environment, open a Julia REPL in the root of the
  Pigeons repo:

  ```julia-repo
  julia> ] # press ] to drop into pkg-mode
  pkg> activate --temp

  pkg> add LiveServer

  pkg> # backspace out of pkg-mode

  julia> using LiveServer

  julia> serve(dir="docs/build")
  ```

If the documentation build hangs (https://github.com/Julia-Tempering/Pigeons.jl/issues/60)
a workaround is the following:

1. start a REPL in VSCode
2. run the documentation from there

## Generating a single page

See `docs/toggle.jl`.
