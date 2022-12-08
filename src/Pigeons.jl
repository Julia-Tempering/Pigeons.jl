module Pigeons

#=
TODO: right now we are exporting too much stuff,
i.e. both mid-level and high-level interfaces.
At some point should transition to either 
only high-level or some kind of switch allowing 
different exports based on MCMC-developer vs 
Bayesian modeller profiles...

Maybe a special macro to export all for e.g. internal dev, testing, etc (e.g. use https://github.com/hayesall/ExportPublic.jl)
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
        Schedule,
        equally_spaced

include("path_implementations.jl")
export  LinearInterpolator,
        create_path,
        TranslatedNormalPath


### Samplers
include("samplers/samplers.jl")

### NRPT
include("acceptance.jl")
include("adaptation.jl")
include("deo.jl")
include("exploration.jl")
include("restarts.jl")
include("NRPT.jl")



### Low-level MPI utilities
include("mpi_utils/LoadBalance.jl")
export  my_global_indices,
        find_process,
        find_local_index,
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

include("swap_graphs.jl")
export deo

include("swap.jl")
export  swap!

### Recorder are used to collect statistics
include("recorder.jl")
export  empty_recorder,
        fit_if_defined!,
        reduced_stats




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
