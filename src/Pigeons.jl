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
using DataStructures
using Preferences
using MPIPreferences
using Expect
using LogExpFunctions

import Serialization.serialize
import Serialization.deserialize
import Base.@kwdef
import Base.show 
import Base.print 
import Base.Threads.@threads
import CRC32c.crc32c
import OnlineStats._fit!
import OnlineStats.value
import OnlineStats._merge!
import Random.rand! 
import Base.(==)
import Pkg.precompile

import DynamicPPL
using Turing

const use_auto_exec_folder = ""

include("includes.jl")

export pigeons, Inputs, PT, 
    Result, 
    ChildProcess, MPI,
    toy_mvn_target,
    index_process, swap_acceptance_pr, log_sum_ratio,
    load,
    setup_mpi, queue_status, kill_job, watch,
    TuringLogPotential, 
    stepping_stone_pair

end # End module


