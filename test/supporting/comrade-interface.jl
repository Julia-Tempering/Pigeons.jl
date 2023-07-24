using Comrade
using Distributions
using Pigeons
using Random
using Serialization
using LogDensityProblemsAD
using LogDensityProblems
using VLBIImagePriors
using LinearAlgebra
using FFTW

const example_dir = abspath(dirname(dirname(pathof(Pigeons))) * "/examples")

if Threads.nthreads() > 1
    error("Some comrade likelihood evaluation may not work under multithreading (FFT stuff)")
end

# Can crash in multithreading even when those are used (see crash-comrade-multithreaded-fft.txt in devnotes)
FFTW.set_num_threads(1) 
LinearAlgebra.BLAS.set_num_threads(1)

import Pigeons.instantiate_target

struct ComradeLogPotential{M}
    post::M
end

struct ComradeLogPrior{M,T}
    prior::M
    transform::T
    dim::Int
    function ComradeLogPrior(post::Comrade.TransformedPosterior)
        t = post.transform
        prior = post.lpost.prior
        return new{typeof(prior), typeof(t)}(prior, t, dimension(post))
    end
end


## LogDensityProblems interfaces 

LogDensityProblems.dimension(lp::ComradeLogPrior) = lp.dim
LogDensityProblems.logdensity(lp::ComradeLogPrior, x) = lp(x)

LogDensityProblems.dimension(lp::ComradeLogPotential) = dimension(lp.post)
LogDensityProblems.logdensity(lp::ComradeLogPotential, x) = lp(x)


# Pigeons interfaces

function (m::ComradeLogPotential)(x)
    # This one takes in the log jacobian of the transformation not the prior!
    # i.e. (after clarification with Paul) the log Jacobian is not added twice!
    logdensityof(m.post, x) 
end

function (m::ComradeLogPrior)(x)
    y, lj = Comrade.transform_and_logjac(m.transform, x)
    return logdensityof(m.prior, y) + lj
end

function Pigeons.initialization(target::ComradeLogPotential, rng::AbstractRNG, ::Int64)
    prior_pot = ComradeLogPrior(target.post)
    return Comrade.inverse(prior_pot.transform, rand(rng, prior_pot.prior))
end
Pigeons.default_explorer(::ComradeLogPotential) = SliceSampler()
Pigeons.default_reference(target::ComradeLogPotential) = ComradeLogPrior(target.post)
function Pigeons.sample_iid!(target::ComradeLogPrior, replica, shared)
    replica.state = Comrade.inverse(target.transform, rand(replica.rng, target.prior))
end



### Examples

function model(θ) 
    (;radius, width, α, β, f, σG, τG, ξG, xG, yG) = θ
    ring = f*smoothed(stretched(MRing((α,), (β,)), radius, radius), width)
    g = (1-f)*shifted(rotated(stretched(Gaussian(), σG, σG*(1+τG)), ξG), xG, yG)
    return ring + g
end

# This one out of sync (maybe need the dev version of Comrade?)
function model(θ, metadata) # From: hybrid
    (;c, f, r, σ, ma, mp, fg, σg, τg, ξg) = θ
    (; grid, cache) = metadata
    ## Form the image model
    img = IntensityMap(f*(1-fg)*c, grid)
    mimg = ContinuousImage(img, cache)
    ## Form the ring model
    s,c = sincos(mp)
    α = ma*c
    β = ma*s
    ring = ((1-f)*(1-fg))*smoothed(stretched(MRing(α, β), r, r),σ)
    gauss = fg*rotated(stretched(Gaussian(), σg, σg*(1+τg)), ξg)
    return mimg + (ring + gauss)
end

# This one out of sync (maybe need the dev version of Comrade?)
function model_closures(θ, metadata)
    (;c) = θ
    (; grid, cache) = metadata
    ## Construct the image model
    img = IntensityMap(c, grid)
    return  ContinuousImage(img, cache)
end

function comrade_target_example()
    dlcamp = deserialize("$example_dir/data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.dlcamp.jl")
    dcphase = deserialize("$example_dir/data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.dcphase.jl")
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
    return ComradeLogPotential(asflat(post))
end

# This one out of sync (maybe need the dev version of Comrade?)
"""
Good candidate to try adaptive paths. 
"""
function comrade_target_hybrid(npix = 6) 
    dlcamp = deserialize("$example_dir/data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.hybrid.dlcamp.jl")
    dcphase = deserialize("$example_dir/data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.hybrid.dcphase.jl")
    
    fovxy  = μas2rad(90.0)
    grid   = imagepixels(fovxy, fovxy, npix, npix)
    buffer = IntensityMap(zeros(npix,npix), grid)

    cache  = create_cache(DFTAlg(dlcamp), buffer, BSplinePulse{3}())
    metadata = (;grid, cache)
    lklhd = RadioLikelihood(model, metadata, dlcamp, dcphase)
    prior = (
          c  = ImageDirichlet(1.0, npix, npix),
          f  = Uniform(0.0, 1.0),
          r  = Uniform(μas2rad(10.0), μas2rad(30.0)),
          σ  = Uniform(μas2rad(0.5), μas2rad(20.0)),
          ma = Uniform(0.0, 0.5),
          mp = Uniform(0.0, 2π),
          fg = Uniform(0.2, 1.0),
          σg = Uniform(μas2rad(50.0), μas2rad(500.0)),
          τg = Uniform(0.0, 1.0),
          ξg = Uniform(0, π)
        )

    post = Posterior(lklhd, prior)
    return ComradeLogPotential(asflat(post))
end

# This one out of sync (maybe need the dev version of Comrade?)
"""
Explicitly identified as being multi-modal.
"""
function comrade_target_closures(npix = 7)
    dlcamp = deserialize("$example_dir/data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.closures.dlcamp.jl")
    dcphase = deserialize("$example_dir/data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.closures.dcphase.jl")

    fovxy = μas2rad(77.5)
    grid = imagepixels(fovxy, fovxy, npix, npix)
    buffer = IntensityMap(zeros(npix,npix), grid)
    cache = create_cache(DFTAlg(dlcamp), buffer, BSplinePulse{3}())
    metadata = (;grid, cache)

    (;X, Y) = grid
    prior = (c = ImageDirichlet(1.0, npix, npix), )

    lklhd = RadioLikelihood(model_closures, metadata, dlcamp, dcphase)
    post = Posterior(lklhd, prior)
    return ComradeLogPotential(asflat(post))
end

nothing