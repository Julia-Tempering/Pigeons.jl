#=
- run from the examples directory
- if in the process of developping Pigeons, make sure to call Pkg.develop("Pigeons") so 
    that the dep in Manifest point to the local file rather than the last published 
=#

using Pkg
Pkg.activate(".")

using Comrade
using Distributions
using Pigeons
using Serialization

include("comrade-interface.jl")

dlcamp = deserialize("data/dlcamp.jl")
dcphase = deserialize("data/dcphase.jl")

# From Comrade examples:
function model(θ)
    (;radius, width, α, β, f, σG, τG, ξG, xG, yG) = θ
    ring = f*smoothed(stretched(MRing((α,), (β,)), radius, radius), width)
    g = (1-f)*shifted(rotated(stretched(Gaussian(), σG, σG*(1+τG)), ξG), xG, yG)
    return ring + g
end
lklhd = RadioLikelihood(model, dlcamp, dcphase)
prior = (
          radius = Uniform(μas2rad(10.0), μas2rad(30.0)),
          width = Uniform(μas2rad(1.0), μas2rad(10.0)),
          α = Uniform(-0.5, 0.5),
          β = Uniform(-0.5, 0.5),
          f = Uniform(0.0, 1.0),
          σG = Uniform(μas2rad(1.0), μas2rad(40.0)),
          τG = Uniform(0.0, 0.75),
          ξG = Uniform(0.0, 1π),
          xG = Uniform(-μas2rad(80.0), μas2rad(80.0)),
          yG = Uniform(-μas2rad(80.0), μas2rad(80.0))
        )
post = Posterior(lklhd, prior)

plp = PigeonsLogPotential(asflat(post))
pt = pigeons(target = plp, n_rounds = 2);

nothing;