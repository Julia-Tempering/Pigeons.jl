module ParallelTempering 
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
include("explorationkernels.jl")
include("hmc.jl")
include("slice_sampling.jl")

### NRPT
include("etas.jl")
include("acceptance.jl")
include("communicationbarrier.jl")
include("updateschedule.jl")
include("roundtriprate.jl")
include("lognormalizingconstant.jl")
include("deoscan.jl")
include("deo.jl")
include("NRPT.jl")

### Useful tools
include("Winsorized_mean.jl")
include("Winsorized_std.jl")

end