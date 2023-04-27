using Comrade
using Jube
using VLBIImagePriors
using Distributions
using ComradePigeons
using Random
using FFTW
FFTW.set_provider!("mkl")
LinearAlgebra.BLAS.set_num_threads(1)
FFTW.set_num_threads(1)

function model_jube(θ, metadata)
    (;m_d, spin, θo, rpeak, pa, p1, p2, χ, ι, βv, spec_index, cross_spec_index) = θ
    θs = π/2
    acc = Jube.JuKeBOX(metadata.nmax, spin, spec_index, cross_spec_index, rpeak, p1, p2, βv, χ, ι, χ+π)
    observer = Jube.AssymptoticObserver(1, θo)
    m = JKConeModel(acc, θs, observer)
    mm = modify(m, Stretch(μas2rad(m_d), μas2rad(m_d)), Rotate(pa))
    mimg = Comrade.modelimage(mm, metadata.cache, false)
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

rng = Random.default_rng()

obs = load_ehtim_uvfits(joinpath(dirname(pathof(Comrade)), "..", "examples", "SR1_M87_2017_096_lo_hops_netcal_StokesI.uvfits"))

obs = scan_average(obs.flag_uvdist(uv_min=0.1e9)).add_fractional_noise(0.02)

# Now, we extract our closure quantities from the EHT data set.
dlcamp = extract_lcamp(obs; snrcut=3.0)
dcphase = extract_cphase(obs; snrcut=3.0)


fovxy = μas2rad(80.0)
npix = 32
grid = imagepixels(fovxy, fovxy, npix, npix)
buffer = IntensityMap(zeros(npix, npix), grid)
cache = create_cache(NFFTAlg(dlcamp; fftflags=FFTW.ESTIMATE), buffer, BSplinePulse{3}())
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

lklhd = RadioLikelihood(model_jube, metadata, dlcamp, dcphase)
post = Posterior(lklhd, prior)

tpost = asflat(post)