module Pigeons

using Base: Forward
using Distributions
using StatsBase
using Interpolations
using Roots
using Dates

export NRPT, slice_sample, SS

### Samplers
include("samplers/samplers.jl")

### NRPT
include("acceptance.jl")
include("adaptation.jl")
include("deo.jl")
include("exploration.jl")
include("restarts.jl")
include("NRPT.jl")

### Other
include("utils.jl")
include("summary.jl")

end # End module
