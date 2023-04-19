module Pigeons

import SplittableRandoms: SplittableRandom, split

import MPI: Comm, Allreduce, Comm_rank, 
            Isend, Irecv!, Recv!, COMM_WORLD, 
            Comm_size, Comm_rank, Init, 
            Comm_dup, Request, Waitall,
            RequestSet, mpiexec, Allreduce, 
            Allgather, Comm_split, isend, recv,
            bcast, tag_ub 

     
using Base: Forward
using Distributions
using StatsBase
using Interpolations
using Roots
using Dates
using OnlineStats
using MacroTools
using DocStringExtensions
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
using StaticArrays
using Printf
using Statistics
using RecipesBase

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
import Base.keys
import Statistics.mean 
import Statistics.var

import DynamicPPL

const use_auto_exec_folder = ""

include("includes.jl")

export pigeons, Inputs, PT, 
    # methods for running jobs:
    ChildProcess, MPI,
    # targets:
    toy_mvn_target, TuringLogPotential,
    # recorders:
    index_process, swap_acceptance_pr, log_sum_ratio, target_online, round_trip, energy_ac1, traces,
    # utils to run on scheduler:
    Result, load, setup_mpi, queue_status, queue_ncpus_free, kill_job, watch,
    # getting information out of an execution:
    stepping_stone_pair, n_tempered_restarts, n_round_trips,
    # variational references:
    GaussianReference, NoVarReference
end # End module


