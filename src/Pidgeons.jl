module Pidgeons

using Base: Forward
using Distributions
using StatsBase
using StatsFuns
using ForwardDiff
using Interpolations
using Roots
using Dates

export nrpt, DEO, computeEtas, roundtrip, restarts

### Samplers
include("samplers/slice_sample.jl")

### NRPT
include("acceptance.jl")
include("adaptation.jl")
include("deo.jl")
include("exploration.jl")
include("restarts.jl")
include("NRPT.jl")

### Utility functions
include("utils.jl")

end # End module
