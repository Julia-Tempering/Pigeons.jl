module Pigeons

#=
TODO: right now we are exporting too much stuff,
i.e. both mid-level and high-level interfaces.
At some point should transition to either 
only high-level or some kind of switch allowing 
different exports based on MCMC-developer vs 
Bayesian modeller profiles...

We do want all these to be documented though 
(and certainly not every single private one, so 
keep it like that for now)

Maybe build some macro(s) to control export granularity 
    for e.g. internal dev, testing, etc (e.g. use https://github.com/hayesall/ExportPublic.jl)
    with the default for most user still just 'using Pigeons'
=#


import SplittableRandoms: SplittableRandom, split

import MPI: Comm, Allreduce, Comm_rank, 
            Isend, Irecv!, Recv!, COMM_WORLD, 
            Comm_size, Comm_rank, Init, 
            Comm_dup, Request, Waitall,
            RequestSet, mpiexec, Allreduce, 
            Allgather, Comm_split, isend, recv,
            bcast

            
using Base: Forward
using Distributions
using StatsBase
using Interpolations
using Roots
using Dates
using OnlineStats
using MacroTools
using DocStringExtensions
using Plots
using LinearAlgebra
using SpecialFunctions

export NRPT, slice_sample, SS

include("utils.jl")
export  split_slice,
        mpi_test,
        @informal, 
        informal_doc

### Paths, discretization, log_potentials
include("log_potential.jl")
include("log_potentials.jl")
export log_unnormalized_ratio

include("path.jl")
export  interpolate

include("discretize.jl")
export  discretize,
        Schedule

include("path_implementations.jl")
export  LinearInterpolator,
        create_path,
        TranslatedNormalPath,
        ScaledPrecisionNormalPath,
        scaled_normal_example,
        analytic_cumulativebarrier


### Samplers
include("samplers/samplers.jl")

### NRPT
include("acceptance.jl")
include("adaptation.jl")
export communicationbarrier

include("deo.jl")
include("exploration.jl")
include("restarts.jl")
include("NRPT.jl")



### Low-level MPI utilities
include("mpi_utils/LoadBalance.jl")
export  my_global_indices,
        find_process,
        find_local_index,
        find_global_index,
        my_load

include("mpi_utils/Entanglement.jl")
export  Entangler,
        transmit,
        transmit!,
        reduce_deterministically,
        all_reduce_deterministically

include("mpi_utils/PermutedDistributedArray.jl")
export  PermutedDistributedArray,
        permuted_get,
        permuted_set!

include("mpi_utils/one_per_host.jl")
export one_per_host

### Mid-level swap APIs
include("Replica.jl")
export  Replica,
        chain,
        recorder

include("pair_swapper.jl")
export swap_decision,
       swap_stat,
       record_swap_stats!


include("replicas.jl")
export  swap!,
        locals,
        load,
        n_chains_global,
        create_vector_replicas,
        n_chains_global,
        initialization,
        create_vector_replicas

include("EntangledReplicas.jl")
export  EntangledReplicas,
        entangler,
        create_entangled_replicas

include("swap_graph.jl")
export deo

include("swap.jl")
export  swap!,
        index_process_plot

### Recorder are used to collect statistics
include("recorders.jl")
export  recorder_keys,
        custom_recorders
include("recorder.jl")
export  default_recorders,
        record!,
        reduced_recorders




include("summary.jl")

end # End module

"""
Instructions to develop:

julia
using Pkg
using Revise
Pkg.activate(".")
using Pigeons

"""
