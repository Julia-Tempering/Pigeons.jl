using Pigeons
using Distributions
using Random
using Turing

import Pigeons: SliceSampler, slice_sample!

include("../src/examples/turing.jl")

"""
Run from runtests.jl
"""

function test_slice_sampler_vector()
    rng = MersenneTwister(1)
    log_potential = (x) -> logpdf(Bernoulli(0.5), x[1]) + logpdf(Normal(0.0, 1.0), x[2])
    h = SliceSampler()
    state = Any[0, 0.0]
    n = 1000
    states = Vector{typeof(state)}(undef, n)
    for i in 1:n
        slice_sample!(h, state, log_potential, rng)
        states[i] = copy(state)
    end
    @assert all(abs.(mean(states) - [0.5, 0.0]) .≤ 0.1)
    @assert all(abs.(std(states) - [0.5, 1.0]) .≤ 0.1)
end

function test_slice_sampler_Turing()
    rng = MersenneTwister(1)
    model = flip_model_modified()
    log_potential = TuringLogPotential(model)
    h = SliceSampler()
    vi = DynamicPPL.VarInfo(rng, model, DynamicPPL.SampleFromPrior(), DynamicPPL.PriorContext()) 
    n = 100
    states = Vector{Float64}(undef, n)
    for i in 1:n
        slice_sample!(h, vi, log_potential, rng)
        states[i] = vi.metadata[1].vals[1]
    end
    @assert abs(mean(states) - 0.5) ≤ 0.1
end

function test_slice_sampler()
    test_slice_sampler_vector()
    test_slice_sampler_Turing()
end

test_slice_sampler_Turing()
