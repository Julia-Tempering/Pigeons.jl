```@meta
CurrentModule = Pigeons
```

# [Output for custom types](@id output-custom-types)

Much of the discussion on sample post-processing 
so far has focussed on cases where [`state`](@ref)'s 
are real or integer 
vectors. 

We discuss here how to post-process samples when they are 
custom data types. 


## Example of custom state

As a concrete example, we consider an implementation of 
an Ising model where a state contains a matrix of 
binary variables as well as some other caches. 
The full example can be [found here](https://github.com/Julia-Tempering/Pigeons.jl/blob/main/examples/ising.jl), 
the only snippet needed from this file is:

```
mutable struct IsingState 
    matrix::BitMatrix 
    [some cache variable, etc...]
end
```



## Flattening into a vector

The [`sample_array`](@ref) function is convenient but it assumes that the variables are real or integer 
vectors (the latter coerced into the former). 

In some cases custom types can be "flattened" into a vector. 
For example, a 2D Ising grid can be reshaped into a vector.

To perform flattening, add a dispatch to Pigeons' [`extract_sample`](@ref). 
Here is how this would be done for the same Ising example as above:

```@example
include("../../examples/ising.jl")

Pigeons.extract_sample(state::IsingState, log_potential) = copy(vec(state.matrix))

pt = pigeons(target = IsingLogPotential(1.0, 2), record = [traces])

using MCMCChains
using StatsPlots

samples = Chains(sample_array(pt))
my_plot = StatsPlots.plot(samples)
StatsPlots.savefig(my_plot, "posterior_densities_and_traces_ising.html"); 
nothing # hide
```

```@raw html
<iframe src="../posterior_densities_and_traces_ising.html" style="height:500px;width:100%;"></iframe>
```


## Trace processing without flattening

It is also possible to process in-memory traces without flattening. 
To do so, the function [`extract_sample`](@ref) should still be extended to 
perform a copy of the relevant parts of the state. 
Then to access the trace, use [`get_sample`](@ref):

```@example nonflat
include("../../examples/ising.jl")

Pigeons.extract_sample(state::IsingState, log_potential) = copy(state.matrix)

pt = pigeons(target = IsingLogPotential(1.0, 2), record = [traces])

vector = get_sample(pt)

eltype(vector)
```
