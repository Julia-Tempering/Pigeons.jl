function test_BufferedAD_usage(pt)
    replica = pt.replicas[2]
    int_lp = Pigeons.find_log_potential(replica, pt.shared.tempering, pt.shared)
    int_ad = ADgradient(pt.shared.explorer.default_autodiff_backend, int_lp, replica.recorders.buffers)
    @test int_ad isa Pigeons.InterpolatedAD
    @test int_ad.ref_ad isa Pigeons.BufferedAD{<:LogDensityProblemsAD.ADGradientWrapper}
    @test int_ad.target_ad isa Pigeons.BufferedAD{<:LogDensityProblemsAD.ADGradientWrapper}
    @test int_ad.ref_ad.buffer === int_ad.target_ad.buffer # ref and target share the same buffer
    @test int_ad.ref_ad.buffer != zero(int_ad.ref_ad.buffer) # buffers were used in the pigeons() call
end

@testset "ForwardDiff" begin
    target = Pigeons.toy_turing_unid_target()
    pt = pigeons(target = target, explorer = AutoMALA(), n_chains=3, n_rounds=1)

    # check that we actually used the buffered implementation
    test_BufferedAD_usage(pt)
end

using Enzyme

@testset "Enzyme: autoMALA on custom Julia target" begin
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
    
    my_log_potential = CustomUnidTarget(100, 50)
    
    Pigeons.initialization(::CustomUnidTarget, ::AbstractRNG, ::Int) = [0.5, 0.5]
    
    function Pigeons.sample_iid!(::CustomUnidTarget, replica, shared)
        state = replica.state 
        rng = replica.rng 
        rand!(rng, state)
    end
    
    LogDensityProblems.dimension(lp::CustomUnidTarget) = 2
    LogDensityProblems.logdensity(lp::CustomUnidTarget, x) = lp(x)
    
    pt = pigeons(
            target = CustomUnidTarget(100, 50), 
            reference = CustomUnidTarget(0, 0), 
            n_chains = 4,
            explorer = AutoMALA(default_autodiff_backend = :Enzyme) 
    )

    # check that we actually used the buffered Enzyme implementation
    test_BufferedAD_usage(pt)
end
