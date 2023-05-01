import Pigeons: SliceSampler, slice_sample!, get_initial_logp

include("turing.jl")

"""
Run from runtests.jl
"""

function test_slice_sampler_vector()
    rng = SplittableRandom(1)
    log_potential = (x) -> logpdf(Bernoulli(0.5), x[1]) + logpdf(Normal(0.0, 1.0), x[2])
    h = SliceSampler()
    state = Number[0, 0.0]
    n = 1000
    states = Vector{typeof(state)}(undef, n)
    cached_lp = -Inf
    for i in 1:n
        cached_lp = slice_sample!(h, state, log_potential, cached_lp, rng)
        states[i] = copy(state)
    end
    @test all(abs.(mean(states) - [0.5, 0.0]) .≤ 0.2)
    @test all(abs.(std(states) - [0.5, 1.0]) .≤ 0.2)
end

function test_slice_sampler_Turing()
    rng = SplittableRandom(1)
    model = flip_model_modified()
    log_potential = TuringLogPotential(model)
    h = SliceSampler()
    vi = DynamicPPL.VarInfo(rng, model, DynamicPPL.SampleFromPrior(), DynamicPPL.PriorContext()) 
    n = 100
    states = Vector{Float64}(undef, n)
    cached_lp = -Inf
    for i in 1:n
        cached_lp = slice_sample!(h, vi, log_potential, cached_lp, rng)
        states[i] = vi.metadata[1].vals[1]
    end
    @test abs(mean(states) - 0.5) ≤ 0.2
end

function test_slice_sampler()
    test_slice_sampler_vector()
    test_slice_sampler_Turing()
end
