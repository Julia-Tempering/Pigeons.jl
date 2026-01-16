module Pigeons

import SplittableRandoms: SplittableRandom, split

import MPI: Comm, Allreduce, Comm_rank,
            Isend, Irecv!, Recv!, COMM_WORLD,
            Comm_size, Comm_rank, Init,
            Comm_dup, Request, Waitall,
            RequestSet, mpiexec, Allreduce,
            Allgather, Comm_split, isend, recv,
            bcast, tag_ub

using ADTypes
using DataFrames
using DataStructures
using Dates
using Distributions
using DocStringExtensions
using Expect
using FillArrays
using Graphs
using Interpolations
using JSON
using LinearAlgebra
using LogDensityProblems
using LogDensityProblemsAD
using LogExpFunctions
using MPIPreferences
using MacroTools
using OnlineStatsBase
using OrderedCollections
using Printf
using Random
using RecipesBase
using Roots
using Serialization
using SpecialFunctions: beta
using StaticArraysCore
using Statistics
using StatsBase
using ZipFile

import Base: Forward, @kwdef, show, print, merge, keys
import Base.Threads.@threads
import OnlineStatsBase: _fit!, value, _merge!
import Random.rand!
import Serialization: serialize, deserialize
import Statistics: mean, var

const use_auto_exec_folder = "use_auto_exec_folder"

include("includes.jl")

export pigeons, Inputs, PT,
    # for running jobs:
    ChildProcess, MPIProcesses,
    # targets:
    TuringLogPotential, StanLogPotential, DistributionLogPotential, JuliaBUGSPath,
    # some examples
    toy_mvn_target, toy_stan_target,
    # post-processing helpers
    sample_array, sample_names, increment_n_rounds!,
    # recorders:
    index_process, swap_acceptance_pr, log_sum_ratio, online, round_trip, energy_ac1, traces, disk,
    record_online, record_default,
    # utils to run on scheduler:
    Result, setup_mpi, queue_status, queue_ncpus_free, kill_job, watch,
    # load, <- removed to avoid clash - see https://github.com/Julia-Tempering/Pigeons.jl/issues/200
    # getting information out of an execution:
    stepping_stone, n_tempered_restarts, n_round_trips, process_sample, get_sample,
    # variational references:
    GaussianReference,
    # samplers
    SliceSampler, AutoMALA, Compose, AAPS, MALA, Mix



# This is required to make extensions work with < 1.9 versions
if !isdefined(Base, :get_extension)
    using Requires
    # I need to explicitly do using here for Requires to work
    using SplittableRandoms
end

@static if !isdefined(Base, :get_extension)
    function __init__()
        @require BridgeStan = "c88b6f0a-829e-4b0b-94b7-f06ab5908f5a" include(joinpath(@__DIR__, "../ext/PigeonsBridgeStanExt/PigeonsBridgeStanExt.jl"))
        @require DynamicPPL = "366bfd00-2699-11ea-058f-f148b4cae6d8" include(joinpath(@__DIR__, "../ext/PigeonsDynamicPPLExt/PigeonsDynamicPPLExt.jl"))
        @require Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9" include(joinpath(@__DIR__, "../ext/PigeonsEnzymeExt/PigeonsEnzymeExt.jl"))
        @require ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210" include(joinpath(@__DIR__, "../ext/PigeonsForwardDiffExt/PigeonsForwardDiffExt.jl"))
        @require HypothesisTests = "09f84164-cd44-5f33-b23f-e6b0d136a0d5" include(joinpath(@__DIR__, "../ext/PigeonsHypothesisTestsExt/PigeonsHypothesisTestsExt.jl"))
        @require JuliaBUGS = "ba9fb4c0-828e-4473-b6a1-cd2560fee5bf" include(joinpath(@__DIR__, "../ext/PigeonsJuliaBUGSExt/PigeonsJuliaBUGSExt.jl"))
        @require MCMCChains = "c7f686f2-ff18-58e9-bc7b-31028e88f75d" include(joinpath(@__DIR__, "../ext/PigeonsMCMCChainsExt/PigeonsMCMCChainsExt.jl"))
        @require ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267" include(joinpath(@__DIR__, "../ext/PigeonsReverseDiffExt/PigeonsReverseDiffExt.jl"))
    end
end


end # End module
