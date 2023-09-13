```@meta
CurrentModule = Pigeons
```

# Distributed sampling over MPI using Pigeons 

## [Running MPI locally](@id mpi-local)

To run MPI locally on one machine, using 4 MPI processes, use:

```@example local
using Pigeons
result = pigeons(
    target = toy_mvn_target(100), 
    checkpoint = true, 
    on = ChildProcess(
            n_local_mpi_processes = 4))
```

Note that if `n_local_mpi_processes` exceeds the number of cores, performance 
will steeply degrade (in contrast to threads, for which performance degrades 
much more gracefully when the number of threads exceeds the number of cores). 

Using `on = ChildProcess(...)` is also useful to change the 
number of threads without having to restart the Julia session. 
For example, to start 4 child processes, each with two threads concurrently sharing work 
across the chains, use:

```@example local
result = pigeons(
    target = toy_mvn_target(100), 
    multithreaded = true, 
    checkpoint = true, 
    on = ChildProcess(
            n_local_mpi_processes = 4,
            n_threads = 2))
```

Alternatively, if instead of using the 2 threads to parallelize across chain, we want to use
them to parallelize e.g. a custom likelihood evalutation over datapoints, set `multithreaded = false` to 
indicate to pigeons it is not responsible for the multithreading (`multithreaded = false` is the default behaviour):

```@example local
result = pigeons(
    target = toy_mvn_target(100), 
    multithreaded = false, # can be skipped, the default  
    checkpoint = true, 
    on = ChildProcess(
            n_local_mpi_processes = 4,
            n_threads = 2))
```

To analyze the output, see the documentation page on [post-processing for MPI runs](@ref output-mpi-postprocessing). Briefly, one option is to load the state of the sampler 
back to your interactive chain via: 

```@example local
pt = load(result) # possible thanks to 'pigeons(..., checkpoint = true)' used above
```

## Running MPI on a cluster

!!! note "The magic of distributed Parallel Tempering"

    If the dimensionality of the state space is large, you may worry that 
    the time to transmit states over the network would dominate the running time. 
    Remarkably, the size of the messages transmitted in the inner loop of our 
    algorithm does **not** depend on the state space. In a nutshell, the 
    machines only need to transmit the value of log density ratios (a single float). 
    See [Algorithm 5 in Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464)
    for details.

MPI is typically available via a cluster scheduling system. At the time of 
writing, [PBS](https://github.com/openpbs/openpbs) and 
[SLURM](https://slurm.schedmd.com/documentation.html) are supported, 
and an experimental implementation of [LSF](https://www.ibm.com/docs/en/spectrum-lsf/10.1.0?topic=overview-lsf-introduction) is included. 
Create an issue if you would like another submission system included. 

Follow these instructions to run MPI over several machines:

1. In the cluster login node, follow the [local installation instructions](@ref installing-pigeons). 
2. Start Julia in the login node, and perform a one-time setup. Read the documentation at [`setup_mpi()`](@ref) for more information. 
3. Still in the Julia REPL running in the login node, use:

```
mpi_run = pigeons(
    target = toy_mvn_target(1000000), 
    n_chains = 1000,
    checkpoint = true,
    on = MPI(
        n_mpi_processes = 1000,
        n_threads = 1))
```

This will start a distributed PT algorithm with 1000 chains on 1000 MPI processes, each using one thread, targeting a one million 
dimensional target distribution. On the UBC Sockeye cluster, the last 
round of this run (i.e. the last 1024 iterations) takes 10 seconds to complete, versus more than 
2 hours if run serially, i.e. a >700x speed-up. 
This is reasonably close to the theoretical 1000x speedup, i.e. we see that the communication costs are negligible. 

You can "watch" the progress of your job (queue status and 
standard output once it is available), using:

```
watch(mpi_run)
```


and cancel/kill a job using 

```
kill_job(mpi_run)
```

To analyze the output, see the documentation page on [post-processing for MPI runs](@ref output-mpi-postprocessing). In a nutshell, one option is to load the state of the sampler 
back to your interactive chain via: 

```
pt = load(mpi_run) # possible thanks to 'pigeons(..., checkpoint = true)' used above
```


## Code dependencies

So far we have used examples where the target, explorers, etc 
are built-in inside the Pigeons module. 
However in typical use cases,
some user-provided code needs to be provided to 
[`ChildProcess`](@ref) 
and [`MPI`](@ref) so that the other participating Julia 
processes have access to it. 
This is done with the argument `dependencies` (of type `Vector`;  present in 
both [`ChildProcess`](@ref) 
and [`MPI`](@ref)). 
Two types of elements can be used in the vector of dependencies, and they can be mixed:

- elements of type `Module`: for each of those, an `using` statement will be generated in the script used by the child process;
- elements of type `String`: a path to a Julia file defining functions and types, for each of those an `include` call is generated. 

Here is an example where we run a custom Ising model in a child process:

```@example deps
using Pigeons

# making the path absolute can be necessary in some contexts:
ising_path = pkgdir(Pigeons) * "/examples/ising.jl"
lazy_path = pkgdir(Pigeons) * "/examples/lazy-ising.jl"

pigeons(
    # see examples/lazy-ising.jl why we need Lazy (Documenter.jl-specific issue)
    target = Pigeons.LazyTarget(Val(:IsingLogPotential)), 
    checkpoint = true,  
    on = ChildProcess(
            n_local_mpi_processes = 2,
            dependencies = [
                Pigeons, # <- Pigeons itself can be skipped, added automatically
                ising_path, # <- these are needed for this example to work
                lazy_path   # <--+
            ]

        )
    )
```

Note the use of `LazyTarget(..)`. 
When starting a child process, the arguments of `pigeons(...)` are used to create 
an [`Inputs`](@ref) struct, which is serialized. 
In certain corner cases this serialization may not be possible, for example if the 
target depends on external processes, or here due to the fact that Documenter.jl 
defines temporary environments (see examples/lazy-ising.jl for details).
In these corner cases, you can use a [`LazyTarget`](@ref) to delay the creation of the 
target so that it is performed in the child processes instead of the calling process.

!!! note

    In order for the child processes to be able to load the same module versions as 
    the current process, the current process calls `Base.active_project()` and 
    pass that information to the child processes. The child processes will activate 
    that environment before proceeding to sampling.

    We therefore assume that the environment given by `Base.active_project()` is 
    in working order.



