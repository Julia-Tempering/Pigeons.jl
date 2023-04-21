# run from the examples directory

using Pkg
Pkg.activate(".")

using Comrade
using Distributions
using Pigeons

include("comrade-interface.jl")

# From Comrade examples:
obs = load_ehtim_uvfits("data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits")
obs = scan_average(obs.flag_uvdist(uv_min=0.1e9))
dlcamp = extract_lcamp(obs)
dcphase = extract_cphase(obs)
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

plp = ComradePigeons.PigeonsLogPotential(asflat(post))
pigeons(target = plp);

nothing;