using Enzyme
using FillArrays
using Mooncake
using ReverseDiff

function allapprox(f, xs; kwargs...)
    ys = map(f, xs)
    m = mean(ys)
    all(y -> isapprox(y, m; kwargs...), ys)
end

function test_BufferedAD_usage(pt)
    replica = last(pt.replicas)
    backend = pt.shared.explorer.default_autodiff_backend
    
    # BufferedAD were created and stored
    @test haskey(replica.recorders.ad_buffers.contents, :target)
    @test haskey(replica.recorders.ad_buffers.contents, :reference)
    
    # ADgradient uses the stored BufferedAD 
    int_lp = Pigeons.find_log_potential(replica, pt.shared.tempering, pt.shared)
    int_ad = ADgradient(backend, int_lp, replica)
    @test int_ad isa Pigeons.InterpolatedAD
    @test int_ad.ref_ad === replica.recorders.ad_buffers.contents[:reference]
    @test int_ad.target_ad === replica.recorders.ad_buffers.contents[:target]
    
    # check that the stored BufferedAD is the correct one
    # NB: can only check type equality because extra buffers can be different (e.g. for StanLogPotential)
    ref_ad = ADgradient(backend, int_lp.path.ref, replica)
    target_ad = ADgradient(backend, int_lp.path.target, replica)
    @test typeof(int_ad.ref_ad) === typeof(ref_ad)
    @test typeof(int_ad.target_ad) === typeof(target_ad)

    # check that buffer is used, and that target and ref share the same gradient buffer
    dy = last(LogDensityProblems.logdensity_and_gradient(int_ad.target_ad, fill(0.5,2)))
    if int_ad.ref_ad.buffer isa DiffResults.MutableDiffResult
        @test DiffResults.gradient(int_ad.ref_ad.buffer) === DiffResults.gradient(int_ad.target_ad.buffer)
        @test DiffResults.gradient(int_ad.target_ad.buffer) === dy
    else
        @test int_ad.ref_ad.buffer === int_ad.target_ad.buffer
        @test int_ad.target_ad.buffer === dy
    end
end

@testset "DynamicPPL targets" begin
    target = Pigeons.toy_turing_unid_target(100)
    dppl_backends = (
        AutoForwardDiff(),
        AutoReverseDiff(compile=false),
        AutoReverseDiff(compile=true),
        AutoMooncake(nothing)
    )
    pts = PT[]
    @testset "$(backend)" for backend in dppl_backends
        pt = pigeons(
            target   = target,
            explorer = AutoMALA(default_autodiff_backend=backend),
            n_chains = 4,
            n_rounds = 6
        )
        test_BufferedAD_usage(pt)
        push!(pts, pt)
    end
    @test allapprox(Pigeons.global_barrier, pts)
    @test allapprox(Pigeons.stepping_stone, pts)
end

@testset "Julia target with branching" begin
    struct CustomUnidTarget 
        n_trials::Int
        n_successes::Int
    end
    
    function (log_potential::CustomUnidTarget)(x) 
        p1, p2 = x
        if !(0 < p1 < 1) || !(0 < p2 < 1)
            return -Inf64 
        end
        p = p1 * p2
        logpdf(Binomial(log_potential.n_trials, p), log_potential.n_successes)
    end
       
    Pigeons.initialization(::CustomUnidTarget, ::AbstractRNG, ::Int) = [0.5, 0.5]
    
    function Pigeons.sample_iid!(::CustomUnidTarget, replica, shared)
        state = replica.state 
        rng = replica.rng 
        rand!(rng, state)
    end
    
    LogDensityProblems.dimension(::CustomUnidTarget) = 2
    LogDensityProblems.logdensity(lp::CustomUnidTarget, x) = lp(x)
    
    target = CustomUnidTarget(100, 50)
    custom_ref = CustomUnidTarget(0, 0)
    dlp_ref = DistributionLogPotential(product_distribution(Fill(Uniform(),2)))

    backends = (AutoForwardDiff(), AutoReverseDiff(), AutoEnzyme())
    @testset "$(typeof(ref))" for ref in (custom_ref, dlp_ref)
        pts = PT[]
        @testset "$backend" for backend in backends 
            pt = pigeons(
                target = target,
                reference = ref, 
                n_chains = 4,
                n_rounds = 6,
                explorer = AutoMALA(default_autodiff_backend = backend) 
            )
            # check that we actually used the buffered implementation
            test_BufferedAD_usage(pt)
            push!(pts, pt)
        end
        @test allapprox(Pigeons.global_barrier, pts)
        @test allapprox(Pigeons.stepping_stone, pts)
    end
end

@testset "Variational reference elides the AD augmentation" begin
    target = Pigeons.toy_stan_unid_target(100)
    pt = pigeons(
        target = target,
        variational = GaussianReference(),
        n_chains = 5,
        n_chains_variational = 5,
        n_rounds = 7
    )
    replica = pt.replicas[end];
    var_ref = pt.shared.tempering.variational_leg.path.ref
    var_ref_ad = Pigeons.get_buffer(replica.recorders.ad_buffers, :reference, Val(:ForwardDiff), var_ref, replica)
    @test var_ref_ad === ADgradient(Val(:ForwardDiff), var_ref, replica)
    @test var_ref_ad != Pigeons.get_buffer(replica.recorders.ad_buffers, :reference, Val(:ForwardDiff), target, replica)
end
