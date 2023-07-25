```@meta
CurrentModule = Pigeons
```

# Distributed sampling over MPI using Pigeons 

## Running MPI locally

To run MPI locally on one machine, using 4 MPI processes and 1 thread per process use:

```@example example
using Pigeons
pigeons(
    target = toy_mvn_target(100), 
    checked_round = 3, 
    checkpoint = true, 
    on = ChildProcess(
            n_local_mpi_processes = 4,
            n_threads = 1))
```

Note that if `n_local_mpi_processes` exceeds the number of cores, performance 
will steeply degrade (in contrast to threads, for which performance degrades 
much more gracefully when the number of threads exceeds the number of cores). 


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

1. In the cluster login node, follow the [local installation instructions](index.html). 
2. Start Julia in the login node, and perform a one-time setup by calling [`setup_mpi()`](@ref). Its argument are the fields in [`MPISettings`](@ref), see the documentation there for details.
3. Still in the Julia REPL running in the login node, use:

```
mpi_run = pigeons(
    target = toy_mvn_target(1000000), 
    n_chains = 1000,
    on = MPI(
        n_mpi_processes = 1000,
        n_threads = 1))
```

This will start a distributed PT algorithm with 1000 chains on 1000 MPI processes, each using one thread, targeting a one million 
dimensional target distribution. On the UBC Sockeye cluster, the last 
round of this run (i.e. the last 1024 iterations) takes 10 seconds to complete, versus more than 
2 hours if ran serially, i.e. a >700x speed-up. 
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

To analyze the output, see the documentation page on [post-processing for MPI runs](output-mpi-postprocessing.html).