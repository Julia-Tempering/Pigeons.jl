module Pigeons

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
using Serialization
using ConcreteStructs

import Base./
import Serialization.serialize
import Serialization.deserialize
import Base.@kwdef
import Base.Threads.@threads


export NRPT, slice_sample, SS

include("utils/misc.jl")
export  split_slice,
        mpi_test

include("utils/informal.jl")
export  @informal,
        informal_doc

include("utils/exec_folder.jl")
export  exec_folder

include("utils/Immutable.jl")
export  Immutable,
        serialize_immutables,
        deserialize_immutables


### Paths, discretization, log_potentials
include("log_potentials/log_potential.jl")
include("log_potentials/log_potentials.jl")
export log_unnormalized_ratio

include("paths/path.jl")
export  interpolate

include("schedules/Schedule.jl")
export Schedule

include("schedules/discretize.jl")
export  discretize

include("paths/path_implementations.jl")
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
        all_reduce_deterministically,
        mpi_needed

include("mpi_utils/PermutedDistributedArray.jl")
export  PermutedDistributedArray,
        permuted_get,
        permuted_set!

include("mpi_utils/one_per_host.jl")
export one_per_host

### Mid-level swap APIs
include("pt/Shared.jl")
include("replicas/Replica.jl")
export  Replica,
        chain,
        recorder

include("swap/pair_swapper.jl")
export swap_decision,
       swap_stat,
       record_swap_stats!,
       SwapStat

include("replicas/replicas.jl")
export  swap!,
        locals,
        load,
        n_chains,
        create_vector_replicas,
        initialization,
        create_replicas,
        FromCheckpoint,
        entangler,
        set_shared

include("replicas/EntangledReplicas.jl")
export  EntangledReplicas,
        create_entangled_replicas

include("swap/swap_graph.jl")
include("swap/swap_graphs.jl") # TODO: exports?

include("swap/swap.jl")
export  swap!,
        index_process_plot

### Recorder are used to collect statistics

include("recorders/Recorders.jl")
export  Recorders,
        record_if_requested!,
        reduce_recorders!

include("recorders/recorder.jl")
export  record!,
        combine!,
        swap_acceptance_probability,
        index_process

include("pt/explorer.jl")
include("pt/Inputs.jl")
export Inputs

include("pt/Iterators.jl")
include("pt/output_files.jl")

include("pt/PT.jl")
export PT

include("pt/Tempering.jl")
include("pt/pt_algorithm.jl")
export  run!

include("summary.jl")

end # End module

"""
Instructions to develop:

julia
using Pkg
using Revise
Pkg.activate(".")
using Pigeons

in = Inputs(inference_problem = Pigeons.ScaledPrecisionNormalPath(1))
pt = PT(in)

"""

