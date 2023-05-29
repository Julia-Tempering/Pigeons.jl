# make sure we are using the version contained 
# in whatever state the parent directory is; 
# this is the intended behaviour both for CI and 
# local development
using Pkg
script_dir = @__DIR__
Pkg.activate(script_dir)
parent_dir = dirname(script_dir)
Pkg.develop(PackageSpec(path=parent_dir))

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