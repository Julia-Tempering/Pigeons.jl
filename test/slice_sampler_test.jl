using Pigeons
using Distributions
using Random

import Pigeons: SliceSampler, slice_sample!

"""
Run from runtests.jl
"""

function test_slice_sampler()
    rng = MersenneTwister(1)
    # log_potential = (x) -> logpdf(Normal(0.0, 1.0), x[1])
    # log_potential = (x) -> logpdf(Normal(0.0, 1.0), x[1]) + logpdf(Normal(3.0, 1.0), x[2])
    # log_potential = (x) -> logpdf(Bernoulli(0.5), x[1])
    log_potential = (x) -> logpdf(Bernoulli(0.5), x[1]) + logpdf(Normal(0.0, 1.0), x[2])
    n = 1000
    h = SliceSampler()
    states = Vector{Vector{Float64}}(undef, n)
    state = Any[0, 0.0] # change to float or int depending on model...
    for i in 1:n
        slice_sample!(h, state, log_potential, rng)
        println(state)
        states[i] = copy(state)
    end
    println(mean(states))
    println(std(states))
    # @assert abs(mean(states)[1] - 0.0) ≤ 0.1
    # @assert abs(std(states)[1] - 1.0) ≤ 0.1
end

test_slice_sampler()
