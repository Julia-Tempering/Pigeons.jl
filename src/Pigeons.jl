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

import Serialization.serialize
import Serialization.deserialize
import Base.@kwdef
import Base.show 
import Base.print 
import Base.Threads.@threads
import CRC32c.crc32c

import DynamicPPL

const use_auto_exec_folder = ""

include("includes.jl")

export pigeons, Inputs, PT, 
    Resume, Result, 
    ToNewProcess, ToMPI,
    toy_mvn_target,
    index_process, swap_acceptance_pr, 
    load

end # End module

"""
Instructions to develop:

julia
using Pkg
using Revise
Pkg.activate(".")
using Pigeons

"""

