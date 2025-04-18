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
pt = Pigeons.load(result) # possible thanks to 'pigeons(..., checkpoint = true)' used above
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

The main three steps to run MPI over several machines are given below. 
For more information, please read [the detailed instructions](#Details-on-setting-up-Pigeons-with-multi-node-MPI).

1. In the cluster login node, follow the [local installation instructions](@ref installing-pigeons). 
2. Start Julia in the login node, and perform a one-time setup. Read the documentation at [`setup_mpi()`](@ref) for more information. 
3. Still in the Julia REPL running in the login node, use the following syntax:

```
mpi_run = pigeons(
    target = toy_mvn_target(1000000), 
    n_chains = 1000,
    checkpoint = true,
    on = MPIProcesses(
        n_mpi_processes = 1000,
        n_threads = 1))
```

This will start a distributed PT algorithm with 1000 chains on 1000 MPIProcesses processes, each using one thread, targeting a one million 
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
pt = Pigeons.load(mpi_run) # possible thanks to 'pigeons(..., checkpoint = true)' used above
```



## Code dependencies

So far we have used examples where the target, explorers, etc 
are built-in inside the Pigeons module. 
However in typical use cases,
some user-provided code needs to be provided to 
[`ChildProcess`](@ref) 
and [`MPIProcesses`](@ref) so that the other participating Julia 
processes have access to it. 
This is done with the argument `dependencies` (of type `Vector`;  present in 
both [`ChildProcess`](@ref) 
and [`MPIProcesses`](@ref)). 
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


## Details on setting up Pigeons with multi-node MPI

We provide more details here to get Pigeons to work on HPC clusters with MPI, 
specifically to 
allow Pigeons processes across several machines to communicate with each 
other. 


### Understanding your HPC cluster

Read the documentation of your HPC cluster or contact the administrator to 
find answers to the following questions:

- What are the locations in the file system that are shared between nodes? 
    Which ones are read/write vs read only? 
- Login nodes and compute nodes will often behave differently. 
    In particular they might have different read/write access in the various volumes. 
- Are there HPC modules that need to be loaded to run MPI jobs?
- Optional: Is there a Julia install provided (e.g., vi HPC modules)? 
- Optional: is there an example showing how to use MPI.jl? 


### Installing Julia on HPC

Check first if an HPC module is available with a recent version of Julia. 
If not, it is easy to install 
one yourself (no root access needed). We explain how to in this section.

As of 2024, we have encountered issues with `juliaup`  
on HPC and recommend instead a simple approach:

- Create a `bin` directory in a volume that is readable on all nodes. 
    E.g., it could be `~/bin`. Go to that directory with `cd`. 
- Follow [these instructions](https://julialang.org/downloads/platform/#linux_and_freebsd), 
    including the step on how to add Julia to your `PATH` variable in `~/.bashrc`. 


### The Julia depot

Julia's package manager (Pkg.jl) stores a large number of files in a 
directory called the *Julia depot*. Julia will look for the envirnonment variable 
`JULIA_DEPOT` to find that directory. 

The standard approach is to have one such Julia depot per user in a shared (network) drive
with read and write access from all nodes. 
However, having many files in a shared drive can make the Pkg operations and 
pre-compilation extremely slow. If you see this issue, two possible options:

- If your HPC architecture has a *burst buffer*, this will be a good place to 
    locate the Julia depot. You may need to request allocation, but it is well worth 
    doing so as it creates a huge performance boost on Pkg and precompile operations.
- If not, a workaround is described [in this page](https://github.com/UBC-Stat-ML/zip_depot).


### Setting up a Julia project

It should be in a volume with read/write access from all nodes.
For testing purpose, it can simply be an empty directory. 
`cd` into it and start julia.

Activate the project and install Pigeons in it by using:

```
] activate . 
add Pigeons
```

### Load MPI modules

During the MPI setup process (next step), the MPI library will need 
to be loaded in order for Pigeons to find it (more precisely, Pigeons will 
call MPIPreferences.jl). 

To see if you need to do this, try `which mpiexec`: if it finds mpiexec, 
you are probably good to go and can go to next step, otherwise, read 
the cluster documentation or talk to the cluster administrator.

This is system-dependent, so it might be done by default, or may 
require loading certain modules, e.g., on certain systems this may look like:

```
module load gcc
module load openmpi
```

Keep note of the list of modules needed, you will need it later in the process.


### Setting up Pigeons MPI

We now need to tell Pigeons how to bind to the HPC's MPI. 
This needs to be done only once per project. 

#### Presets

Look first at the list of clusters that have "presets" available, by 
typing `Pigeons.setup_mpi_` and then tab. These presets are the most straightforward to use.
If there is a preset available for your system, just run that command and you 
are done! 

For example, on most Digital Research Alliance of Canada HPC clusters (formerly Compute Canada), you can simply use:

```
Pigeons.setup_mpi_compute_canada()
```

#### Calling [`setup_mpi()`](@ref)

If a preset is not available, manual configuration can be done using 
[`Pigeons.setup_mpi()`](@ref). To get more information on the 
arguments to pass in to `Pigeons.setup_mpi()`, see [`MPISettings`](@ref), but we walk over the main steps here. 

##### Submission system

The argument `submission_system` should specify the queue 
submission system. Most popular choices are `:pbs` and 
`:slurm`. Pigeons will use this information to generate 
the queue submission scripts.

Optionally, you can use also `add_to_submission` to add 
extra information in the queue submission script. 

See also [presets.jl](https://github.com/Julia-Tempering/Pigeons.jl/blob/main/src/submission/presets.jl) for examples of 
what this looks like in different existing systems. 
When you submit MPI jobs, you can see the generated script 
in `results/latest/.submission_script.sh`. 

Here is an example of what a generated script 
looks like if we add 
`add_to_submission = ["source ~/bin/zip_depot/bin/load_depot"]` 
as needed for using [the zip_depot utility](https://github.com/UBC-Stat-ML/zip_depot): 

```
#!/bin/bash
#SBATCH -t 00:05:00
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=8gb 

#SBATCH --job-name=2025-04-09-18-04-55-fltVoqC0
#SBATCH -o /home/bouchar3/Pigeons.jl/results/all/2025-04-09-18-04-55-fltVoqC0/info/stdout.txt
#SBATCH -e /home/bouchar3/Pigeons.jl/results/all/2025-04-09-18-04-55-fltVoqC0/info/stderr.txt
source ~/bin/zip_depot/bin/load_depot # <-- this is where 'add_to_submission' entries are added

cd $SLURM_SUBMIT_DIR
module load julia/1.11.3
MPI_OUTPUT_PATH="/home/bouchar3/Pigeons.jl/results/all/2025-04-09-18-04-55-fltVoqC0"

mpiexec --output-filename "$MPI_OUTPUT_PATH/mpi_out" --merge-stderr-to-stdout   /cvmfs/soft.computecanada.ca/easybuild/software/2023/x86-64-v3/Core/julia/1.11.3/bin/julia -C native -J/cvmfs/soft.computecanada.ca/easybuild/software/2023/x86-64-v3/Core/julia/1.11.3/lib/julia/sys.so -g1 --startup-file=no --banner=no --project=/home/bouchar3/Pigeons.jl --threads=1 --compiled-modules=existing /home/bouchar3/Pigeons.jl/results/all/2025-04-09-18-04-55-fltVoqC0/.launch_script.jl
```

##### Environment modules 

The HPC modules you are currently using for the setup will need 
to be added to the generated script, so Pigeons needs to know about them. Add them to the `environment_modules` argument of 
`setup_mpi()`. 

##### Library name

In most cases, the MPI system library is found automatically, so try 
first leaving `library_name` to its default value of `nothing`. 
If not, see the documentation in [`MPISettings`](@ref) under 
`library_name`. 

##### Customizing the mpiexec command

In many HPC clusters, the command `mpiexec` is used to submit jobs to MPI. 
This is the default value in Pigeons' generated submission scripts. 
In other clusters, a different command is used. 
We describe here how to perform this customization. 

The main mechanism is the argument `mpiexec` specified when calling [`setup_mpi()`](@ref), 
for example, on some cluster you may need:

```
Pigeons.setup_mpi(
    mpiexec = "srun -n \$SLURM_NTASKS --mpi=pmi2",
    ...
)
```

Minor note: in order to be able to use the convenience function 
[`watch()`](@ref), used to show standard output of MPI jobs, you need 
to ensure MPI will create output files at the right location. 
For mpiexec, this is achieved with the default arguments of `mpiexec`: 
see the source 
code of [`MPISettings`](@ref). 

If you need to change argument for a single job, 
additional arguments to `mpiexec` (or alternatives such as `srun`) 
can be provided in the argument `mpiexec_args` in [`MPIProcesses`](@ref). 


#### Testing your MPI setup

Use the following to start MPI over two MPI processes for 
quick testing:

```
using Pigeons 
result = pigeons(
            target = toy_mvn_target(10), 
            on = MPIProcesses(walltime = "00:05:00"), 
            checkpoint = true)
```

Then use: 

```
watch(result)
```

To see the output. You can also look at the following 
files to help you troubleshoot potential issues, all found 
in `results/all/latest` (or `results/all/[time]/`):

- `.submission_script.sh`: the file submitted to the queue,
- `.launch_script.jl`: the script started on each node,
- `info/submission_output.txt`: the output of submitting the job to the queue,
- `info/stderr.txt` and `info/stdout.txt`: the slurm/pbs output,
- `mpi_out`: the mpiexec output, organized by node (internally, Pigeons suppresses most output on all nodes except the one at rank 0).  


#### Creating a PR with your cluster's setup

Once you have determined what options to pass in to 
[`setup_mpi`](@ref), please consider creating a Pull Request 
adding one function in the file 
[presets.jl](https://github.com/Julia-Tempering/Pigeons.jl/blob/main/src/submission/presets.jl). Thank you!
