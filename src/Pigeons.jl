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
using Random 
using Graphs

import Base./
import Serialization.serialize
import Serialization.deserialize
import Base.@kwdef
import Base.show 
import Base.print 
import Base.Threads.@threads
import CRC32c.crc32c

# include()'s generated using: sort_includes("Pigeons.jl")
include("utils/exec_folder.jl")
include("utils/Indexer.jl")
include("utils/misc.jl")
include("utils/Immutable.jl")
include("utils/@informal.jl")
include("swap/DEO.jl")
include("schedules/Schedule.jl")
include("schedules/discretize.jl")
include("samplers/hmc.jl")
include("samplers/SliceSampler.jl")
include("pt/output_files.jl")
include("pt/Iterators.jl")
include("pt/Inputs.jl")
include("pt/Shared.jl")
include("swap/swap_graphs.jl")
include("pt/PT.jl")
include("tempering/NonReversiblePT.jl")
include("tempering/tempering.jl")
include("swap/swap_graph.jl")
include("replicas/Replica.jl")
include("swap/pair_swapper.jl")
include("recorders/recorders.jl")
include("recorders/recorder.jl")
include("pt/pt_algorithm.jl")
include("pt/checks.jl")
include("pt/checkpoint.jl")
include("paths/path.jl")
include("paths/ScaledPrecisionNormalPath.jl")
include("paths/InterpolatingPath.jl")
include("targets/target.jl")
include("mpi_utils/one_per_host.jl")
include("mpi_utils/LoadBalance.jl")
include("mpi_utils/Entangler.jl")
include("mpi_utils/PermutedDistributedArray.jl")
include("replicas/EntangledReplicas.jl")
include("swap/swap.jl")
include("replicas/replicas.jl")
include("log_potentials/log_potentials.jl")
include("log_potentials/log_potential.jl")
include("explorers/explorer.jl")
include("explorers/ToyExplorer.jl")
include("targets/toy_mvn_target.jl")
include("restarts.jl")
include("exploration.jl")
include("api.jl")
include("adaptation.jl")
include("acceptance.jl")
include("NRPT.jl")
include("deo.jl")

export pigeons, Inputs, PT, 
    Resume, Result, 
    ToNewProcess, ToMPI,
    toy_mvn_target,
    index_process, swap_acceptance_pr

end # End module

"""
Instructions to develop:

julia
using Pkg
using Revise
Pkg.activate(".")
using Pigeons

"""

