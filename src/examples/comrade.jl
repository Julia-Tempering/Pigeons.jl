#=
From: https://github.com/ptiede/Comrade.jl/blob/main/lib/ComradePigeons/src/ComradePigeons.jl
Note: copying this here is temporary!
TODO: find nice way to bridge Comrade and Pigeons 
        Requires seemed promising but would cause 
        problems with current custom MPI submission, 
        wait to hear about potential switch to 
        MPIServerManagers?
=#

struct PigeonsLogPotential{M}
    post::M
end

# This one takes in the log jacobian of the transformation not the prior!
function (m::PigeonsLogPotential)(x)
    return logdensityof(m.post, x)
end

# Pigeons.@provides target PigeonsLogPotential(model::Comrade.TransformedPosterior) =
#     PigeonsLogPotential(model)

Pigeons.create_state_initializer(target::PigeonsLogPotential, ::Inputs) = target
function Pigeons.initialization(target::PigeonsLogPotential, rng::Pigeons.SplittableRandom, _::Int64)
   return  Comrade.prior_sample(rng, target.post)
end

Pigeons.create_explorer(::PigeonsLogPotential, ::Inputs) = Pigeons.SliceSampler()

Pigeons.create_reference_log_potential(target::PigeonsLogPotential, ::Inputs) = PriorPotential(target.post)

function Pigeons.sample_iid!(target::PigeonsLogPotential, replica)
    replica.state = initialization(target, replica.rng, replica.replica_index)
end




struct PriorPotential{M,T}
    prior::M
    transform::T
    function PriorPotential(post::Comrade.TransformedPosterior)
        t = post.transform
        prior = post.lpost.prior
        return new{typeof(prior), typeof(t)}(prior, t)
    end
end

function (m::PriorPotential)(x)
    y, lj = Comrade.transform_and_logjac(m.transform, x)
    return logdensityof(m.prior, y) + lj
end

function Pigeons.sample_iid!(target::PriorPotential, replica)
    replica.state = Comrade.inverse(target.transform, rand(replica.rng, target.prior))
end



# an example 


# Build the Model. Here we we a struct to hold some caches
# which will speed up imaging
# For our model we will be using a rasterized image. This can be viewed as something like a
# non-parametric model. As a result of this we will need to use a `modelimage` object to
# store cache information we will need to compute the numerical FT.
function model(θ, metadata)
    (;c) = θ
    (; cache, grid) = metadata
    #Construct the image model
    imap = IntensityMap(c, grid)
    cimg = ContinuousImage(imap, cache)
    #Create the modelimage object that will use a cache to compute the DFT
    return cimg
end

function comrade_serialize!()
    obs = Comrade.load_ehtim_uvfits("$(pkgdir(Pigeons))/examples/SR1_M87_2017_096_hi_hops_netcal_StokesI.uvfits")
    obs.add_scans()
    # kill 0-baselines since we don't care about
    # large scale flux and make scan-average data
    obs = scan_average(obs).add_fractional_noise(0.02)
    # extract log closure amplitudes and closure phases
    dlcamp = extract_lcamp(obs)
    dcphase = extract_cphase(obs)

    serialize("$(pkgdir(Pigeons))/examples/SR1_M87_2017_096_hi_hops_netcal_StokesI.uvfits.dlcamp.jls", dlcamp)
    serialize("$(pkgdir(Pigeons))/examples/SR1_M87_2017_096_hi_hops_netcal_StokesI.uvfits.dcphase.jls", dcphase)
    return nothing
end

function comrade_example()

    dlcamp = deserialize("$(pkgdir(Pigeons))/examples/SR1_M87_2017_096_hi_hops_netcal_StokesI.uvfits.dlcamp.jls")
    dcphase = deserialize("$(pkgdir(Pigeons))/examples/SR1_M87_2017_096_hi_hops_netcal_StokesI.uvfits.dcphase.jls")

    # Set up the grid
    npix = 8
    fovxy = μas2rad(72.0)
    # Now we can feed in the array information to form the cache. We will be using a DFT since
    # it is efficient for so few pixels
    grid = imagepixels(fovxy, fovxy, npix, npix)
    # We will use a Dirichlet prior to enforce that the flux sums to unity since closures are
    # degenerate to total flux.
    pulse = BSplinePulse{3}()
    img = IntensityMap(zeros(npix,npix), grid)
    cache = create_cache(DFTAlg(dlcamp), img, pulse)
    metadata = (;cache, img, grid, pulse)
    prior = (c = ImageDirichlet(0.5, npix, npix),)

    lklhd = RadioLikelihood(model, metadata, dlcamp, dcphase)
    post = Posterior(lklhd, prior)

    # Transform from simplex space to the unconstrained
    tpost = asflat(post)

    return PigeonsLogPotential(tpost)
end

