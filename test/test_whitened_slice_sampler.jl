using HypothesisTests

include("supporting/turing_models.jl")

# a non-allocating Gaussian log-potential, used as a target and as a reference
struct WSSGaussian
    μ::Vector{Float64}
    P::Matrix{Float64}
end
function (g::WSSGaussian)(x)
    q = 0.0
    @inbounds for j in eachindex(x), i in eachindex(x)
        q += (x[i] - g.μ[i]) * g.P[i, j] * (x[j] - g.μ[j])
    end
    return -q / 2
end
Pigeons.initialization(g::WSSGaussian, ::AbstractRNG, ::Int) = copy(g.μ)
# only valid for a standard normal reference
Pigeons.sample_iid!(::WSSGaussian, replica, shared) = randn!(replica.rng, replica.state)

function wss_record_allocations(recorder, x)
    # reach a capacity of 10 records, then empty and record again
    foreach(t -> Pigeons.record!(recorder, (1, t, x)), 1:10)
    empty!(recorder)
    Pigeons.record!(recorder, (1, 1, x))
    return @allocated Pigeons.record!(recorder, (1, 2, x))
end

function wss_step_allocations(explorer, replica, shared)
    Pigeons.step!(explorer, replica, shared)
    return @allocated Pigeons.step!(explorer, replica, shared)
end

@testset "Construction" begin
    @test WhitenedSliceSampler().A isa Matrix{Float64}
    @test WhitenedSliceSampler(whitening = "diagonal").A isa Diagonal{Float64}
    @test WhitenedSliceSampler(whitening = :diagonal).A isa Diagonal{Float64}
    @test Pigeons.is_identity(WhitenedSliceSampler())
    @test_throws ArgumentError WhitenedSliceSampler(whitening = "cholesky")
    @test_throws ArgumentError WhitenedSliceSampler(w = 0.0)
    @test_throws ArgumentError WhitenedSliceSampler(first_tuning_round = 0)
    @test_throws ArgumentError WhitenedSliceSampler(min_samples = 1)
    @test_throws ArgumentError WhitenedSliceSampler(max_scale_change = 1.0)
    @test_throws ArgumentError WhitenedSliceSampler(eigen_floor = 1.0)
    @test_throws DimensionMismatch WhitenedSliceSampler(WhitenedSliceSampler(), zeros(2), zeros(2, 2), zeros(3, 3))
end

@testset "Target state recorder" begin
    rng = Xoshiro(1)
    X = randn(rng, 200, 4) * [1 0 0 0; 0.9 0.3 0 0; 0 0 2 0; 0 0 1 1]
    a, b = Pigeons.whitened_slice_covariance(), Pigeons.whitened_slice_covariance()
    foreach(i -> Pigeons.record!(i ≤ 70 ? a : b, (1, i, X[i, :])), axes(X, 1))
    m = merge(b, a) # out of order: sorted by scan
    @test Pigeons.nsamples(m) == 200
    Y, ranges = Pigeons.ordered_states(m)
    @test Y == X' && ranges == [1:200]
    μ, Σ = Pigeons.sample_moments(Y)
    @test μ ≈ vec(mean(X; dims = 1))
    @test Σ ≈ cov(X)
    @test merge(Pigeons.whitened_slice_covariance(), a).states == a.states
    # two chains
    foreach(i -> Pigeons.record!(m, (2, i, X[i, :])), 1:10)
    @test Pigeons.ordered_states(m)[2] == [1:200, 201:210]
    @test_throws DimensionMismatch Pigeons.record!(m, (1, 300, [1.0]))
    # no allocations once the capacity has been reached
    empty!(a)
    @test Pigeons.nsamples(a) == 0
    @test wss_record_allocations(a, X[1, :]) == 0
end

@testset "Effective number of samples" begin
    rng = Xoshiro(3)
    n, ρ = 4096, 0.9
    X = zeros(n, 2)
    for t in 2:n
        X[t, 1] = ρ * X[t - 1, 1] + sqrt(1 - ρ^2) * randn(rng)
        X[t, 2] = randn(rng)
    end
    whole = Pigeons.whitened_slice_covariance()
    foreach(t -> Pigeons.record!(whole, (1, t, X[t, :])), 1:n)
    # the slowest coordinate has τ = (1 + ρ) / (1 - ρ) = 19
    @test Pigeons.effective_samples(whole) ≈ n * (1 - ρ) / (1 + ρ) rtol = 0.25
    white = Pigeons.whitened_slice_covariance()
    foreach(t -> Pigeons.record!(white, (1, t, X[t, [2, 2]])), 1:n)
    @test Pigeons.effective_samples(white) > 0.8n
    # strong autocorrelation (τ ≈ 199) is not underestimated with few samples
    slow = Pigeons.whitened_slice_covariance()
    let x = 0.0, rng = Xoshiro(4)
        for t in 1:512
            x = 0.99x + sqrt(1 - 0.99^2) * randn(rng)
            Pigeons.record!(slow, (1, t, [x]))
        end
    end
    @test Pigeons.effective_samples(slow) < 20
    # the same chain spread over several replicas, as after swaps
    parts = [Pigeons.whitened_slice_covariance() for _ in 1:3]
    foreach(t -> Pigeons.record!(parts[mod1(t ÷ 5, 3)], (1, t, X[t, :])), 1:n)
    @test Pigeons.effective_samples(reduce(merge, parts)) ≈ Pigeons.effective_samples(whole)
end

@testset "Whitening estimates" begin
    rng = Xoshiro(2)
    Σ = [1.0 0.95 0.0; 0.95 1.0 0.0; 0.0 0.0 1e-4]
    L = cholesky(Σ).L
    recorder = Pigeons.whitened_slice_covariance()
    foreach(t -> Pigeons.record!(recorder, (1, t, [1.0, 2.0, 3.0] .+ L * randn(rng, 3))), 1:10_000)
    for whitening in (:full, :diagonal)
        h = WhitenedSliceSampler(; whitening, max_scale_change = 1e3)
        μ, A, W = Pigeons.estimate_whitening(h, recorder)
        @test μ ≈ [1.0, 2.0, 3.0] atol = 0.05
        @test W * A ≈ I
        Σ̂ = whitening == :full ? Σ : Diagonal(Σ)
        @test A * A' ≈ Σ̂ rtol = 0.05
        # limited change of the scales: the third one cannot go below 1/10
        h = WhitenedSliceSampler(; whitening)
        μ, A, W = Pigeons.estimate_whitening(h, recorder)
        @test minimum(eigvals(Symmetric(Matrix(A * A')))) ≈ 0.01 rtol = 1e-6
        @test (A * A')[1:2, 1:2] ≈ Σ̂[1:2, 1:2] rtol = 0.05
        # ...and the next update is relative to the current whitening
        μ, A, W = Pigeons.estimate_whitening(WhitenedSliceSampler(h, μ, A, W), recorder)
        @test A * A' ≈ Σ̂ rtol = 0.05
    end
    h = WhitenedSliceSampler()
    # degenerate cases: too few samples, non-finite values, a coordinate that never moved
    few = Pigeons.whitened_slice_covariance()
    foreach(t -> Pigeons.record!(few, (1, t, randn(rng, 3))), 1:5)
    @test Pigeons.estimate_whitening(h, few) === nothing
    nonfinite = Pigeons.whitened_slice_covariance()
    foreach(t -> Pigeons.record!(nonfinite, (1, t, [randn(rng), Inf, 0.0])), 1:50)
    @test Pigeons.estimate_whitening(h, nonfinite) === nothing
    stuck = Pigeons.whitened_slice_covariance()
    foreach(t -> Pigeons.record!(stuck, (1, t, [randn(rng), randn(rng), 1.0])), 1:50)
    @test Pigeons.estimate_whitening(h, stuck) === nothing
    # a strongly autocorrelated chain: too few effective samples
    slow = Pigeons.whitened_slice_covariance()
    let x = zeros(3)
        for t in 1:256
            x .= 0.99 .* x .+ sqrt(1 - 0.99^2) .* randn(rng, 3)
            Pigeons.record!(slow, (1, t, x))
        end
    end
    @test Pigeons.effective_samples(slow) < 20
    @test Pigeons.estimate_whitening(WhitenedSliceSampler(min_samples = 20), slow) === nothing
    # exactly degenerate covariance: eigenvalues are floored
    flat = Pigeons.whitened_slice_covariance()
    foreach(t -> (x = randn(rng); Pigeons.record!(flat, (1, t, [x, 2x, randn(rng)]))), 1:1_000)
    μ, A, W = Pigeons.estimate_whitening(WhitenedSliceSampler(min_samples = 2), flat)
    @test all(isfinite, A) && all(isfinite, W)
    @test W * A ≈ I
end

@testset "Identity whitening matches SliceSampler" begin
    # before the first adaptation, the explorer is a SliceSampler with the same settings
    target = toy_mvn_target(3)
    pts = [
        pigeons(; target, explorer, n_rounds = 4, record = [traces], show_report = false)
        for explorer in (SliceSampler(w = 4.0), WhitenedSliceSampler(first_tuning_round = 5))
    ]
    @test sample_array(pts[1]) == sample_array(pts[2])
end

@testset "Invariance under a fixed whitening" begin
    # starting from exact samples of the target, one exploration step with an arbitrary
    # (mismatched) whitening should leave the target distribution invariant
    d = 3
    Σ = [1.0 0.8 0.0; 0.8 1.0 -0.5; 0.0 -0.5 2.0]
    μ = [1.0, -1.0, 0.5]
    target = WSSGaussian(μ, inv(Σ))
    reference = WSSGaussian(zeros(d), Matrix(1.0I, d, d))
    L = cholesky(Σ).L
    for whitening in (:full, :diagonal)
        # the whitening corresponds to a covariance (and a mean) very different from the target ones
        A = whitening == :full ? Matrix(cholesky([4.0 -1.0 0.5; -1.0 0.5 0.0; 0.5 0.0 0.2]).L) : Diagonal(sqrt.([4.0, 0.5, 0.1]))
        W = inv(A)
        explorer = WhitenedSliceSampler(WhitenedSliceSampler(; whitening, n_passes = 1), [3.0, 3.0, -3.0], A, W)
        pt = pigeons(; target, reference, explorer, n_chains = 2, n_rounds = 1, show_report = false)
        @test pt.shared.explorer === explorer
        replica = only(filter(r -> Pigeons.is_target(pt.shared.tempering.swap_graphs, r.chain), pt.replicas))
        rng = Xoshiro(6)
        n = 2_000
        samples = zeros(n, d)
        for i in 1:n
            replica.state .= μ .+ L * randn(rng, d)
            Pigeons.step!(explorer, replica, pt.shared)
            samples[i, :] = replica.state
        end
        for j in 1:d
            @test pvalue(ExactOneSampleKSTest(samples[:, j], Normal(μ[j], sqrt(Σ[j, j])))) > 0.001
        end
        # a linear combination checks the joint distribution
        v = [1.0, -2.0, 0.5]
        @test pvalue(ExactOneSampleKSTest(samples * v, Normal(v' * μ, sqrt(v' * Σ * v)))) > 0.001
    end
end

@testset "Correlated Gaussian target" begin
    d = 5
    Σ = [0.99^abs(i - j) for i in 1:d, j in 1:d] .* ((1:d) ./ 100) .* ((1:d) ./ 100)'
    μ = collect(range(-1.0, 1.0, d))
    target = WSSGaussian(μ, inv(Σ))
    reference = WSSGaussian(zeros(d), Matrix(1.0I, d, d))
    for whitening in (:full, :diagonal)
        # a large `max_scale_change`: the scales are 10⁻²-10⁻³ times the initial ones
        explorer = WhitenedSliceSampler(; whitening, first_tuning_round = 4, max_scale_change = 1e3)
        pt = pigeons(; target, reference, explorer, n_chains = 4, n_rounds = 10,
            record = [traces], show_report = false)
        @test !Pigeons.is_identity(pt.shared.explorer)
        samples = sample_array(pt)[(end - 511):end, 1:d, 1]
        @test vec(mean(samples; dims = 1)) ≈ μ atol = 0.03
        if whitening == :full
            @test cov(samples) ≈ Σ rtol = 0.2
            @test pt.shared.explorer.A * pt.shared.explorer.A' ≈ Σ rtol = 0.2
            # allocation-free exploration steps (target chains record their states
            # in vectors whose capacity has been reached in the previous rounds)
            for replica in pt.replicas
                @test wss_step_allocations(pt.shared.explorer, replica, pt.shared) == 0
            end
        end
    end
end

@testset "Checkpoints" begin
    pt = pigeons(target = toy_mvn_target(2), explorer = WhitenedSliceSampler(first_tuning_round = 2),
        n_rounds = 5, checkpoint = true, show_report = false)
    @test !Pigeons.is_identity(pt.shared.explorer)
    pt2 = PT(pt.exec_folder)
    @test Pigeons.recursive_equal(pt.shared.explorer, pt2.shared.explorer)
end

if !is_windows_in_CI()
    @testset "Stan target" begin
        pt = pigeons(target = Pigeons.toy_stan_target(3),
            explorer = WhitenedSliceSampler(first_tuning_round = 3),
            n_rounds = 6, record = [online], show_report = false)
        @test !Pigeons.is_identity(pt.shared.explorer)
        @test length(pt.shared.explorer.μ) == 3
        @test all(isfinite, mean(pt))
    end
end

@testset "Unsupported states" begin
    @test_throws "WhitenedSliceSampler only supports" pigeons(
        target = TuringLogPotential(flip_model_unidentifiable()),
        explorer = WhitenedSliceSampler(), n_rounds = 2, show_report = false)
end
