```@meta
CurrentModule = Pigeons
```


# [Post-processing for MPI runs (plotting, summaries, etc)](@id output-mpi-postprocessing) 

Two options are available to post-process samples produced from 
MPI runs: (1) loading  
the distributed output back into your interactive shell, or (2)
perform post-processing by loading samples from disk one at a time. 

Option (1) is more convenient than (2) but it uses more RAM.


## Loading the distributed output back into your interactive shell

Many of Pigeons' post-processing tools take as input a [`PT`](@ref) struct.
When running locally, [`pigeons()`](@ref) returns a [`PT`](@ref) struct, 
however, when running a job via [`MPI`](@ref) or [`ChildProcess`](@ref), 
[`pigeons()`](@ref) returns a [`Result`](@ref) struct (which only holds the  
directory where samples are stored). 

Use [`load()`](@ref) to convert a [`Result`](@ref) into a 
[`PT`](@ref) struct. 
This will load the information distributed across several machines 
into the interactive node.

Once you have a [`PT`](@ref) struct, proceed in the same way as 
when running PT locally, e.g. [see the page on plotting](@ref output-plotting), 
[the page on online statistics](@ref output-online), 
and [the page on sample summaries and diagnostics](@ref output-numerical).

For example, here is how to modify the posterior density and trace plot 
example from [the plotting page](@ref output-plotting) to run as a local MPI job 
instead of in-process (the lines differing from the local version are marked 
with (*)):

```@example traces
using Pigeons
using MCMCChains
using StatsPlots
plotlyjs()

# example target: Binomial likelihood with parameter p = p1 * p2
an_unidentifiable_model = Pigeons.toy_turing_unid_target(100, 50)

pt_result = pigeons(target = an_unidentifiable_model, 
                # (*) run in two new MPI processes 
                on = ChildProcess(n_local_mpi_processes = 2), 
                # (*) signal that we want the PT object to be 
                #     serialized at the end of each round
                checkpoint = true,
                n_rounds = 12,
                # make sure to record the trace 
                # (each machine keeps its own during sampling)
                record = [traces; round_trip; record_default()])

# (*) load the result across all machines into this interactive node
pt = load(pt_result)

# collect the statistics and convert to MCMCChains' Chains
# to have axes labels matching variable names in Turing and Stan
samples = Chains(sample_array(pt), variable_names(pt))

# create the trace plots
my_plot = StatsPlots.plot(samples)
StatsPlots.savefig(my_plot, "mpi_posterior_densities_and_traces.html"); 
nothing # hide
```

```@raw html
<iframe src="../mpi_posterior_densities_and_traces.html" style="height:500px;width:100%;"></iframe>
```

# Perform post-processing by loading samples from disk one at a time

Here instead of keeping samples in memory, we instruct the machines to 
store them on the fly in a shared directory. 
We do this using the [`disk`](@ref) [`recorder`](@ref). 

Then we process the sample one at the time using [`process_sample()`](@ref). 

Here is an example where the target is 1000-dimensional but we are only 
interested in the first coordinate:

```@example traces
using Pigeons
using Plots

# example target: a 1000 dimensional target
high_d_target = Pigeons.toy_mvn_target(1000)

pt_result = pigeons(target = high_d_target, 
                # run in two new MPI processes 
                on = ChildProcess(n_local_mpi_processes = 2), 
                checkpoint = true,
                # save samples to disk as we go
                record = [disk])

# process the samples one by one, keeping only the first dimension
first_dim_of_each = Vector{Float64}()
process_sample(pt_result) do chain, scan, sample
    # each sample here is a Vector{Float64} of length 1000 
    # in general, it will is produced by extract_sample()
    push!(first_dim_of_each, sample[1])
end

plotlyjs()
myplot = Plots.plot(first_dim_of_each)
Plots.savefig(myplot, "first_dim_of_each.html"); 
nothing # hide
```

```@raw html
<iframe src="../first_dim_of_each.html" style="height:500px;width:100%;"></iframe>
```