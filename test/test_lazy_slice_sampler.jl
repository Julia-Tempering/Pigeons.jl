import Pigeons: LazySliceSampler, Replica

@testset "Lazy slice doubling and acceptance" begin
    h = LazySliceSampler(w = 1.0)
    rng = SplittableRandom(184)
    state = [0.0]
    replica = Replica(state, 1, rng, (;), 1)
    pointer = Ref(state, 1)
    calls = Ref(0)
    bounded(x) = (calls[] += 1; abs(x[1]) <= 8 ? 0.0 : -Inf)
    tracker = Pigeons.SliceBoundsTrackingEvaluator(pointer, bounded, state, -1.0, [0.0, 0.0], Float64[])
    _, _, lp_L, lp_R, cache = Pigeons.slice_double!(tracker, replica, 0.0, h.w)
    @test calls[] <= length(cache) + 2
    @test cache isa Vector{Float64}
    @test lp_L == lp_R == -Inf

    calls[] = 0
    outside(x) = (calls[] += 1; -Inf)
    tracker = Pigeons.SliceBoundsTrackingEvaluator(pointer, outside, state, -1.0, [0.0, 0.0], Float64[])
    _, _, lp_L, lp_R, cache = Pigeons.slice_double!(tracker, replica, 0.0, 1.0)
    @test lp_L == lp_R == -Inf
    @test isempty(cache)
    @test calls[] == 2

    # Check the cached lazy test against Neal's original test on a disconnected slice.
    logp(x) = max(-0.5 * (x[1] + 3)^2, -0.5 * (x[1] - 3)^2)
    original = SliceSampler(w = h.w)
    for _ in 1:500
        x = rand(rng) < 0.5 ? -3.0 : 3.0
        state[1] = x
        z = logp(state) - randexp(rng)
        tracker = Pigeons.SliceBoundsTrackingEvaluator(pointer, logp, state, z, [x, x], Float64[])
        L, R, lp_L, lp_R, cache = Pigeons.slice_double!(tracker, replica, x, h.w)
        for _ in 1:5
            proposal = Pigeons.draw_new_position(L, R, rng)
            state[1] = proposal
            logp(state) >= z || continue
            state[1] = x
            expected = Pigeons.slice_accept(original, replica, proposal, z, L, R, lp_L, lp_R, pointer, logp)
            state[1] = x
            actual = Pigeons.slice_accept!(tracker, replica, x, proposal, L, R, lp_L, lp_R, cache)
            @test actual == expected
        end
    end
end

@testset "Lazy slice width adaptation" begin
    a = Pigeons.slice_bounds()
    b = Pigeons.slice_bounds()
    key = (2, 1)
    for i in 1:100
        z = Float64(i)
        radius = i <= 50 ? 1.0 : 10.0
        observation = (z, 1.5 * radius)
        Pigeons.record!(isodd(i) ? a : b, (key, observation))
    end
    merged = merge(a, b)
    @test length(merged.observations[key]) == 100
    empty!(a)
    @test length(merged.observations[key]) == 100
    h = LazySliceSampler(w = 2.0)
    adapted = Pigeons.adapt_explorer(h, (; slice_bounds = merged), nothing, nothing)
    @test Pigeons.get_w(adapted, key, 100.0) >
          5 * Pigeons.get_w(adapted, key, 1.0)
    @test Pigeons.get_w(adapted, (1, 1), 1.0) == 2.0
    @test isempty(h.widths)
    @test adapted.widths == Pigeons.adapt_explorer(h, (; slice_bounds = merged), nothing, nothing).widths
end

@testset "Lazy slice sampler mixed state" begin
    rng = SplittableRandom(12)
    state = Number[false, 0, 0.0]
    logp(x) = logpdf(Bernoulli(0.5), x[1]) + logpdf(Binomial(10), x[2]) - x[3]^2 / 2
    replica = Replica(state, 1, rng, (;), 1)
    h = LazySliceSampler(w = 2.0)
    cached_lp = -Inf
    samples = Vector{Vector{Float64}}()
    for _ in 1:2000
        cached_lp = Pigeons.slice_sample!(h, state, logp, cached_lp, replica)
        push!(samples, Float64.(state))
    end
    @test all(abs.(mean(samples) - [0.5, 5.0, 0.0]) .< 0.2)
    @test all(abs.(std(samples) - [0.5, std(Binomial(10)), 1.0]) .< 0.2)
    @test cached_lp == logp(state)
end

@testset "Lazy slice PT adaptation" begin
    target = DistributionLogPotential(Normal())
    pt = pigeons(target = target, reference = target, explorer = LazySliceSampler(w = 1.0),
                 n_chains = 1, n_rounds = 4)
    @test !isempty(pt.shared.explorer.widths)
end

DynamicPPL.@model function lazy_slice_two_variables()
    a ~ Normal()
    b ~ Normal()
    return a + b
end

@testset "Lazy slice DynamicPPL coordinates" begin
    rng = SplittableRandom(31)
    model = lazy_slice_two_variables()
    vi = DynamicPPL.VarInfo(rng, model, DynamicPPL.InitFromPrior())
    vi = DynamicPPL.link(vi, model)
    recorder = Pigeons.slice_bounds()
    replica = Replica(vi, 1, rng, (; slice_bounds = recorder), 1)
    logp = TuringLogPotential(model)
    cached_lp = -Inf
    for _ in 1:20
        cached_lp = Pigeons.slice_sample!(LazySliceSampler(w = 1.0), vi, logp, cached_lp, replica)
    end
    @test haskey(recorder.observations, (1, 1))
    @test haskey(recorder.observations, (1, 2))
end

@testset "Lazy slice invalid initial density" begin
    state = [0.0]
    replica = Replica(state, 1, SplittableRandom(9), (;), 1)
    invalid(x) = NaN
    @test_throws ErrorException Pigeons.slice_sample!(LazySliceSampler(), state, invalid, -Inf, replica)
    @test state == [0.0]
end

@testset "Lazy slice invalid evaluated density" begin
    state = [0.0]
    tracker = Pigeons.SliceBoundsTrackingEvaluator(Ref(state, 1), x -> NaN, state, -1.0, [0.0, 0.0], Float64[])
    @test_logs (:warn, r"LazySliceSampler") @test Pigeons.tracked_slice_eval!(tracker, 1.0) == -Inf
    @test tracker.inside == [0.0, 0.0]
    @test tracker.outside == [1.0]
end
