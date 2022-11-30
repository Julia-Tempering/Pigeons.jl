module Pigeons

import SplittableRandoms: SplittableRandom, split

import MPI: Comm, Allreduce, Comm_rank, 
            Isend, Irecv!, Recv!, COMM_WORLD, 
            Comm_size, Comm_rank, Init, 
            Comm_dup, Request, Waitall,
            RequestSet, mpiexec

using Base: Forward
using Distributions
using StatsBase
using Interpolations
using Roots
using Dates
using OnlineStats

export NRPT, slice_sample, SS

### Paths, discretization, log_potentials
include("log_potentials.jl")
include("path.jl")

### Samplers
include("samplers/samplers.jl")

### NRPT
include("acceptance.jl")
include("adaptation.jl")
include("deo.jl")
include("exploration.jl")
include("restarts.jl")
include("NRPT.jl")

### Other
include("utils.jl")
export  split_slice,
        mpi_test

### Low-level MPI utilities
include("mpi_utils/LoadBalance.jl")
export  my_global_indices,
        find_process,
        find_local_index,
        my_load

include("mpi_utils/Entanglement.jl")
export  Entangler,
        transmit,
        transmit!

include("mpi_utils/PermutedDistributedArray.jl")
export  PermutedDistributedArray,
        permuted_get,
        permuted_set!

### Mid-level swap APIs
include("Replica.jl")
export  Replica,
        chain

include("pair_swapper.jl")
export swap_decision,
       swap_stat

include("replicas.jl")
export  swap!,
        locals,
        load,
        n_chains_global,
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
include("Recorder.jl")




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
