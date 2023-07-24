import Pigeons: SliceSampler, slice_sample!, Replica
using DynamicPPL

struct UnitInterval 
    initialized_inside::Bool
end 
(::UnitInterval)(x) = 0.0 < x[1] < x[2] < x[3] < 1.0 ? 0.0 : -Inf 
Pigeons.default_reference(ui::UnitInterval) = ui
Pigeons.sample_iid!(reference_log_potential::UnitInterval, replica, shared) = nothing
Pigeons.initialization(log_potential::UnitInterval, ::AbstractRNG, ::Int) = [0.5, 0.6, log_potential.initialized_inside ? 0.7 : 0.2]

@testset "ConstrainedSliceSampler" begin
    Test.@test_throws ErrorException pigeons(target = UnitInterval(false))
    pigeons(target = UnitInterval(true))
end

include("supporting/turing_models.jl")

function test_slice_sampler_logprob_counts()
    rng = SplittableRandom(1)
    ct = [0]
    log_potential = function (x)
                        ret = sum(logpdf.(Normal(0.0, 1.0), x))
                        ct[1] += 1
                        return ret
                    end
    h = SliceSampler()
    D = 10
    state = zeros(D)
    n = 1000
    states = Vector{typeof(state)}(undef, n)
    cached_lp = -Inf
    for i in 1:n
        replica = Replica(state, 1, rng, (;), 1)
        cached_lp = slice_sample!(h, state, log_potential, cached_lp, replica)
        states[i] = copy(state)
    end
    println("Total logprob evals: $(ct[1])")
    @test all(abs.(mean(states) - zeros(D)) .≤ 0.2)
    @test all(abs.(std(states) - ones(D)) .≤ 0.2)
end

function test_slice_sampler_vector()
    rng = SplittableRandom(1)
    log_potential = (x) -> logpdf(Bernoulli(0.5), x[1]) + logpdf(Normal(0.0, 1.0), x[2])
    h = SliceSampler()
    state = Number[0, 0.0]
    n = 1000
    states = Vector{typeof(state)}(undef, n)
    cached_lp = -Inf
    for i in 1:n
        replica = Replica(state, 1, rng, (;), 1)
        cached_lp = slice_sample!(h, state, log_potential, cached_lp, replica)
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
        replica = Replica(vi, 1, rng, (;), 1)
        cached_lp = slice_sample!(h, vi, log_potential, cached_lp, replica)
        states[i] = vi.metadata[1].vals[1]
    end
    @test abs(mean(states) - 0.5) ≤ 0.2
end

function test_slice_sampler()
    test_slice_sampler_vector()
    test_slice_sampler_Turing()
    test_slice_sampler_logprob_counts()
end

@testset "SliceSampler" begin
    test_slice_sampler()
end
