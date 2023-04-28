#=
Copied from https://github.com/ptiede/Comrade.jl/blob/main/lib/ComradePigeons/src/ComradePigeons.jl 
ComradePigeons not being published makes it harder to deploy to MPI via 'using ComradePigeons'
As a workaround, including the contents in this repo for now 
=#

# TODO: check with Paul if one of sample_iid!() below is not superfluous? 

using Comrade
using Distributions
using Pigeons
using Serialization
using LogDensityProblemsAD
using LogDensityProblems
using VLBIImagePriors
using LinearAlgebra

# comment if needed; only for the Jube example, obtain via
# dev https://github.com/dchang10/FastElliptic https://github.com/ptiede/Jube
using Jube 
using FFTW

# Do not do the line below in the interface script: race condition when MPI'ed
# FFTW.set_provider!("mkl")

LinearAlgebra.BLAS.set_num_threads(1)

# Setting this to one thread, otherwise crashes (see crash-comrade-multithreaded-fft.txt in devnotes)
FFTW.set_num_threads(1) # Threads.nthreads())

import Pigeons.gradient
import Pigeons.instantiate_target

struct PigeonsLogPotential{M}
    post::M
end

struct PriorPotential{M,T}
    prior::M
    transform::T
    dim::Int
    function PriorPotential(post::Comrade.TransformedPosterior)
        t = post.transform
        prior = post.lpost.prior
        return new{typeof(prior), typeof(t)}(prior, t, dimension(post))
    end
end

LogDensityProblems.dimension(pp::PriorPotential) = pp.dim

# This one takes in the log jacobian of the transformation not the prior!
function (m::PigeonsLogPotential)(x)
    return logdensityof(m.post, x)
end

Pigeons.create_state_initializer(target::PigeonsLogPotential, ::Inputs) = target
function Pigeons.initialization(target::PigeonsLogPotential, rng::Pigeons.SplittableRandom, _::Int64)
   return  Comrade.prior_sample(rng, target.post)
end

Pigeons.default_explorer(::PigeonsLogPotential) = SliceSampler()

Pigeons.create_reference_log_potential(target::PigeonsLogPotential, ::Inputs) = PriorPotential(target.post)

function Pigeons.gradient(log_potential::PigeonsLogPotential, x) 
    calculator = ADgradient(Pigeons.autodiff_backend[], log_potential.post)
    _, gradient = LogDensityProblems.logdensity_and_gradient(calculator, x)
    return gradient
end

function Pigeons.gradient(log_potential::PriorPotential, x) 
    calculator = ADgradient(Pigeons.autodiff_backend[], log_potential)
    _, gradient = LogDensityProblems.logdensity_and_gradient(calculator, x)
    return gradient
end

LogDensityProblems.logdensity(pp::PriorPotential, x) = pp(x)

function Pigeons.sample_iid!(target::PigeonsLogPotential, replica)
    replica.state = initialization(target, replica.rng, replica.replica_index)
end

function Pigeons.sample_iid!(target::PriorPotential, replica)
    replica.state = Comrade.inverse(target.transform, rand(replica.rng, target.prior))
end

function (m::PriorPotential)(x)
    y, lj = Comrade.transform_and_logjac(m.transform, x)
    return logdensityof(m.prior, y) + lj
end

### Example

function model(θ) 
    (;radius, width, α, β, f, σG, τG, ξG, xG, yG) = θ
    ring = f*smoothed(stretched(MRing((α,), (β,)), radius, radius), width)
    g = (1-f)*shifted(rotated(stretched(Gaussian(), σG, σG*(1+τG)), ξG), xG, yG)
    return ring + g
end

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

function model_closures(θ, metadata)
    (;c) = θ
    (; grid, cache) = metadata
    ## Construct the image model
    img = IntensityMap(c, grid)
    return  ContinuousImage(img, cache)
end

function comrade_target_example()
    dlcamp = deserialize("data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.dlcamp.jl")
    dcphase = deserialize("data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.dcphase.jl")
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
    return PigeonsLogPotential(asflat(post))
end

"""
Good candidate to try adaptive paths. 
"""
function comrade_target_hybrid(npix = 6) 
    dlcamp = deserialize("data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.hybrid.dlcamp.jl")
    dcphase = deserialize("data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.hybrid.dcphase.jl")
    
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
    return PigeonsLogPotential(asflat(post))
end

"""
Explicitly identified as being multi-modal.
"""
function comrade_target_closures(npix = 7)
    dlcamp = deserialize("data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.closures.dlcamp.jl")
    dcphase = deserialize("data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.closures.dcphase.jl")

    fovxy = μas2rad(77.5)
    grid = imagepixels(fovxy, fovxy, npix, npix)
    buffer = IntensityMap(zeros(npix,npix), grid)
    cache = create_cache(DFTAlg(dlcamp), buffer, BSplinePulse{3}())
    metadata = (;grid, cache)

    (;X, Y) = grid
    prior = (c = ImageDirichlet(1.0, npix, npix), )

    lklhd = RadioLikelihood(model_closures, metadata, dlcamp, dcphase)
    post = Posterior(lklhd, prior)
    return PigeonsLogPotential(asflat(post))
end



#### Jube 

model_jube(θ, metadata) = model_jube(θ, metadata, false)
model_jube_mt(θ, metadata) = model_jube(θ, metadata, true)

function model_jube(θ, metadata, multithreaded_modelimage)
    (;m_d, spin, θo, rpeak, pa, p1, p2, χ, ι, βv, spec_index, cross_spec_index) = θ
    θs = π/2
    acc = Jube.JuKeBOX(metadata.nmax, spin, spec_index, cross_spec_index, rpeak, p1, p2, βv, χ, ι, χ+π)
    observer = Jube.AssymptoticObserver(1, θo)
    m = JKConeModel(acc, θs, observer)
    mm = modify(m, Stretch(μas2rad(m_d), μas2rad(m_d)), Rotate(pa))
    mimg = Comrade.modelimage(mm, metadata.cache, multithreaded_modelimage)
    return mimg
end


abstract type AccretionModel <: ComradeBase.AbstractModel end
ComradeBase.visanalytic(::Type{<:AccretionModel}) = ComradeBase.NotAnalytic()
ComradeBase.imanalytic(::Type{<:AccretionModel}) = ComradeBase.IsAnalytic()

struct JKConeModel{B,S,O} <: AccretionModel
    acc::B
    s::S
    o::O
end

ComradeBase.isprimitive(::Type{<:JKConeModel}) = ComradeBase.IsPrimitive()

function ComradeBase.intensity_point(s::JKConeModel, p)
    α=p.X
    β=p.Y
    direct  = Jube.raytrace(s.acc, -α, β, s.s, s.o, true)[1]
    indirect = Jube.raytrace(s.acc, -α, β, s.s, s.o, false)[1]

    return direct + indirect

end

# Here we use a LazyTarget because we cannot serialize the FFT plan 

Base.@kwdef struct JubeTarget
    npix = 32 
    use_fft = true
    multithreaded_modelimage = false
end 

function Pigeons.instantiate_target(jube::JubeTarget) 
    npix = jube.npix 
    use_fft = jube.use_fft
    multithreaded_modelimage = jube.multithreaded_modelimage

    dlcamp = deserialize("data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.closures.dlcamp.jl")
    dcphase = deserialize("data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.closures.dcphase.jl")

    fovxy = μas2rad(80.0)
    grid = imagepixels(fovxy, fovxy, npix, npix)
    buffer = IntensityMap(zeros(npix, npix), grid)
    alg = use_fft ? 
        NFFTAlg(dlcamp; fftflags=FFTW.ESTIMATE) :
        DFTAlg(dlcamp)
    cache = create_cache(alg, buffer, BSplinePulse{3}())
    metadata = (;grid, cache, nmax=1)

    (;X, Y) = grid
    prior = (
        m_d = Uniform(2.0, 5.0),
        spin= Uniform(-1.0, 0.01),
        θo  = Uniform(deg2rad(1.0), deg2rad(40.0)),
        rpeak= Uniform(1.0, 10.0),
        pa   = Uniform(0.0, 2π),
        p1   = Uniform(0.1,10.0),
        p2   = Uniform(1.0, 10.0),
        βv   = Uniform(0.0, 0.9),
        χ    = Uniform(-π, 0.0),
        ι    = Uniform(0, π/2),
        spec_index = Uniform(-3.0, 3.0),
        cross_spec_index = Uniform(-3.0, 3.0),

    )

    lklhd = RadioLikelihood(
        multithreaded_modelimage ? model_jube_mt : model_jube, 
        metadata, dlcamp, dcphase)
    post = Posterior(lklhd, prior)

    return PigeonsLogPotential(asflat(post))
end

jube_target = Pigeons.LazyTarget(JubeTarget())
jube_target_mti = Pigeons.LazyTarget(JubeTarget(multithreaded_modelimage = true))

nothing