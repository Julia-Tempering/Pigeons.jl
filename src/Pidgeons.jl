module Pidgeons

using Base: Forward
using Distributions
using StatsBase
using Interpolations
using Roots
using Dates

export NRPT

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
