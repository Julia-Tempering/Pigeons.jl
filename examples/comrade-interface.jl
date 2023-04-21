#=
Copied from https://github.com/ptiede/Comrade.jl/blob/main/lib/ComradePigeons/src/ComradePigeons.jl 
ComradePigeons not being published makes it harder to deploy to MPI via 'using ComradePigeons'
As a workaround, including the contents in this repo for now 
=#

struct PigeonsLogPotential{M}
    post::M
end

# This one takes in the log jacobian of the transformation not the prior!
function (m::PigeonsLogPotential)(x)
    return logdensityof(m.post, x)
end

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

