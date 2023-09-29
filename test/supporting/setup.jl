using DynamicPPL
using BridgeStan

using Pigeons

# all the quick imports
using ArgMacros
using Distributions
using LinearAlgebra
using MPI
using MPIPreferences
using OnlineStats
using Random
using Serialization
using SplittableRandoms
using Statistics
using Test
using ForwardDiff
using LogDensityProblems
using LogDensityProblemsAD

is_windows_in_CI() = Sys.iswindows() && (get(ENV, "CI", "false") == "true")
