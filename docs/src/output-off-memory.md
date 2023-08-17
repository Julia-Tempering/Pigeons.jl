```@meta
CurrentModule = Pigeons
```

# [Off-memory processing](@id output-off-memory)

When the dimensionality of a model is large and/or the 
number of MCMC samples is large, the samples may not 
fit in memory. 
In some situations, it may be possible to compute the 
output in finite memory, as described in 
[the online statistics documentation page](@ref output-online). 
However not all situations admit sufficient statistics and 
in this case it is necessary to store samples to disk. 
We show here how to do so when pigeons is run on a single 
machine, but the interface is similar over MPI and 
described in the 
[MPI sample processing documentation page](@ref output-mpi-postprocessing). 


## Prepare the PT run with the disk recorder

Two options need to be enabled. 
First, `checkpoint = true`, 
which saves a snapshot at the end of each round in 
the directory `results/all/[unique directory]` and 
symlinked to `results/latest`. 
Second, the `disk` recorder:

```@example offmemory
using Pigeons

# example target: a 1000 dimensional target
high_d_target = Pigeons.toy_mvn_target(1000)

pt = pigeons(target = high_d_target, 
                checkpoint = true,
                record = [disk])
```

## Accessing the disk samples 

Use the function [`process_sample()`](@ref) which 
processes the samples one by one and passes it to 
a user-provided function. 
Here we will extract the first dimension of 
each 1000-dimensional vector:

```@example offmemory
# load the samples from disk one by one, keeping only the first dimension
first_dim_of_each = Vector{Float64}()
process_sample(pt) do chain, scan, sample # ordered as if we had an inner loop over scans
    # each sample here is a Vector{Float64} of length 1000 
    # in general, it will is produced by extract_sample()
    push!(first_dim_of_each, sample[1])
end

using Plots
plotlyjs()
myplot = Plots.plot(first_dim_of_each)
Plots.savefig(myplot, "first_dim_of_each.html"); 
nothing # hide
```

```@raw html
<iframe src="../first_dim_of_each.html" style="height:500px;width:100%;"></iframe>
```



## Internal organization of the samples

This section can be skipped. 

The samples are produced in compressed zip 
folders, one for each replica having visited 
the target:

```@example offmemory 
readdir("$(pt.exec_folder)/round=10/samples")
```

In the above example we see that only replicas 
6 and 7 visited the target. Each zip file 
contains serialized .jl files. 
This output organization is used to support 
concurrent and distributed processing. 

Internally, two passes are made, a first one to 
index the samples which are shuffled across
many files. Then they are visited in the correct 
order and passed to the processing function.