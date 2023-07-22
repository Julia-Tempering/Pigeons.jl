include("comrade-interface.jl")

Pkg.develop(url = "https://github.com/dchang10/FastElliptic")
Pkg.develop(url = "https://github.com/ptiede/Jube")

using Jube 


#### Jube: relativistic ray tracing based likelihood model

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

# NB: current issue with jube is that it is not working in 
# multithreading. Simplest example:
#   pigeons(Inputs(target = jube_target, multithreaded = true, n_chains = 4))

# **Update:** the problem is not jube but rather the use of FFTW+multi-threads

Base.@kwdef struct JubeTarget
    npix = 32 
    use_fft = true
    multithreaded_modelimage = false
end 

function Pigeons.instantiate_target(jube::JubeTarget) 
    npix = jube.npix 
    use_fft = jube.use_fft
    multithreaded_modelimage = jube.multithreaded_modelimage

    dlcamp = deserialize("$example_dir/data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.closures.dlcamp.jl")
    dcphase = deserialize("$example_dir/data/SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits.closures.dcphase.jl")

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

    return ComradeLogPotential(asflat(post))
end

jube_target = Pigeons.LazyTarget(JubeTarget())

pt = pigeons(target = jube_target, n_rounds = 2)

nothing