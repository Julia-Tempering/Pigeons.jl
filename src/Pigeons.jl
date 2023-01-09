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
import CRC32c.crc32c

# include()'s generated using: sort_includes("Pigeons.jl")
include("utils/exec_folder.jl")
include("utils/Indexer.jl")
include("utils/misc.jl")
include("utils/Immutable.jl")
include("utils/@informal.jl")
include("swap/swap_graphs.jl")
include("schedules/Schedule.jl")
include("schedules/discretize.jl")
include("samplers/hmc.jl")
include("samplers/SpliceSampler.jl")
include("pt/checks.jl")
include("pt/Iterators.jl")
include("pt/Shared.jl")
include("pt/Inputs.jl")
include("pt/output_files.jl")
include("pt/PT.jl")
include("swap/swap_graph.jl")
include("replicas/Replica.jl")
include("swap/pair_swapper.jl")
include("recorders/recorders.jl")
include("recorders/recorder.jl")
include("pt/pt_algorithm.jl")
include("pt/checkpoint.jl")
include("paths/path.jl")
include("paths/TranslatedNormalPath.jl")
include("paths/ScaledPrecisionNormalPath.jl")
include("pt/tempering.jl")
include("pt/explorer.jl")
include("paths/InterpolatingPath.jl")
include("mpi_utils/one_per_host.jl")
include("mpi_utils/LoadBalance.jl")
include("mpi_utils/Entangler.jl")
include("mpi_utils/PermutedDistributedArray.jl")
include("replicas/EntangledReplicas.jl")
include("swap/swap.jl")
include("replicas/replicas.jl")
include("log_potentials/log_potentials.jl")
include("log_potentials/log_potential.jl")
include("summary.jl")
include("restarts.jl")
include("exploration.jl")
include("api.jl")
include("adaptation.jl")
include("acceptance.jl")
include("NRPT.jl")
include("deo.jl")

export NRPT, slice_sample, SliceSampler


export  split_slice,
        mpi_test

export  @informal,
        informal_doc

export  next_exec_folder

export  Immutable,
        serialize_immutables,
        deserialize_immutables


### Paths, discretization, log_potentials

export log_unnormalized_ratio

export  interpolate

export Schedule

export  discretize

export  LinearInterpolator,
        create_path,
        TranslatedNormalPath,
        ScaledPrecisionNormalPath,
        scaled_normal_example,
        analytic_cumulativebarrier

### Samplers

### NRPT

export communicationbarrier

### Low-level MPI utilities
export  my_global_indices,
        find_process,
        find_local_index,
        find_global_index,
        my_load

export  Entangler,
        transmit,
        transmit!,
        reduce_deterministically,
        all_reduce_deterministically,
        mpi_needed

export  PermutedDistributedArray,
        permuted_get,
        permuted_set!

export one_per_host

### Mid-level swap APIs

export  Replica,
        chain,
        recorder

export swap_decision,
       swap_stat,
       record_swap_stats!,
       SwapStat

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

export  EntangledReplicas,
        create_entangled_replicas

export  swap!,
        index_process_plot

### Recorder are used to collect statistics

export  record_if_requested!,
        reduce_recorders!

export  record!,
        combine!,
        swap_acceptance_probability,
        index_process

export Inputs

export PT, only_one_process

export  run!

export pigeons




end # End module

"""
Instructions to develop:

julia
using Pkg
using Revise
Pkg.activate(".")
using Pigeons

"""

