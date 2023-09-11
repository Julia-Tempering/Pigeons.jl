```@meta
CurrentModule = Pigeons
```

# Parallelization

## Parallel exploration

When `multithreaded = true` is activated, several threads will be used 
concurrently to perform sampling. 
The number of threads will be the minimum of the number of chains 
and `Threads.nthreads()`:

```@example par
using Pigeons
pigeons(
    target = toy_mvn_target(100), 
    n_chains = 2,
    multithreaded = true)
```

Since changing `Threads.nthreads()` requires restarting the Julia 
session, a convenient way to call pigeons with a different number 
of threads is to use `on = ChildProcess(...)` as described 
in [running MPI locally](@ref mpi-local).