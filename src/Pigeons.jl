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
using DataFrames
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
using ZipFile
using ForwardDiff
using LogDensityProblems
using LogDensityProblemsAD

import Serialization.serialize
import Serialization.deserialize
import Base.@kwdef
import Base.show
import Base.print
import Base.Threads.@threads
import OnlineStats._fit!
import OnlineStats.value
import OnlineStats._merge!
import Random.rand!
import Base.(==)
import Base.keys
import Statistics.mean
import Statistics.var
import Base.merge


const use_auto_exec_folder = "use_auto_exec_folder"

include("includes.jl")

export pigeons, Inputs, PT,
    # for running jobs:
    ChildProcess, MPI,
    # references:
    DistributionLogPotential,
    # targets:
    TuringLogPotential, StanLogPotential,
    # some examples
    toy_mvn_target, toy_stan_target,
    # post-processing helpers
    sample_array, variable_names,
    # recorders:
    index_process, swap_acceptance_pr, log_sum_ratio, online, round_trip, energy_ac1, traces, disk,
    record_online, record_default,
    # utils to run on scheduler:
    Result, load, setup_mpi, queue_status, queue_ncpus_free, kill_job, watch,
    # getting information out of an execution:
    stepping_stone, n_tempered_restarts, n_round_trips, process_sample, get_sample,
    # variational references:
    GaussianReference,
    # samplers
    SliceSampler, AutoMALA, Compose, AAPS, MALA



# This is required to make extensions work with < 1.9 versions
if !isdefined(Base, :get_extension)
    using Requires
end

@static if !isdefined(Base, :get_extension)
    function __init__()
        @require DynamicPPL = "366bfd00-2699-11ea-058f-f148b4cae6d8" include(joinpath(@__DIR__, "../ext/PigeonsDynamicPPLExt.jl"))
        @require BridgeStan = "c88b6f0a-829e-4b0b-94b7-f06ab5908f5a" include(joinpath(@__DIR__, "../ext/PigeonsBridgeStanExt.jl"))
    end
end


end # End module
