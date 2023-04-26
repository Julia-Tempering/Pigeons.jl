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

import Pigeons.gradient

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

Pigeons.default_explorer(::PigeonsLogPotential) = Pigeons.HMC(0.1, 10, 3)

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

function comrade_target_example()
    dlcamp = deserialize("data/dlcamp.jl")
    dcphase = deserialize("data/dcphase.jl")
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
