using Enzyme
using ReverseDiff

function test_BufferedAD_usage(pt)
    replica = last(pt.replicas)
    int_lp = Pigeons.find_log_potential(replica, pt.shared.tempering, pt.shared)
    int_ad = ADgradient(pt.shared.explorer.default_autodiff_backend, int_lp, replica)
    @test int_ad isa Pigeons.InterpolatedAD
    @test int_ad.ref_ad isa Pigeons.BufferedAD{<:LogDensityProblemsAD.ADGradientWrapper}
    @test int_ad.target_ad isa Pigeons.BufferedAD{<:LogDensityProblemsAD.ADGradientWrapper}
    @test int_ad.ref_ad.buffer === int_ad.target_ad.buffer # ref and target share the same buffer
    @test int_ad.ref_ad.buffer != zero(int_ad.ref_ad.buffer) # buffers were used in the pigeons() call
end

@testset "Correctness of BufferedAD backends versus Enzyme (unbuffered)" begin
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
    
    LogDensityProblems.dimension(lp::CustomUnidTarget) = 2
    LogDensityProblems.logdensity(lp::CustomUnidTarget, x) = lp(x)
    
    target = CustomUnidTarget(100, 50) 
    reference = CustomUnidTarget(0, 0)
    pt_enzyme = pigeons(
            target = target,
            reference = reference, 
            n_chains = 4,
            n_rounds = 6,
            explorer = AutoMALA(default_autodiff_backend = :Enzyme) 
    )

    @testset "$backend" for backend in (:ForwardDiff, :ReverseDiff)
        pt = pigeons(
            target = target,
            reference = reference, 
            n_chains = 4,
            n_rounds = 6,
            explorer = AutoMALA(default_autodiff_backend = backend) 
        )
        @test abs(Pigeons.global_barrier(pt) - Pigeons.global_barrier(pt_enzyme)) < 1e-8
        @test abs(Pigeons.stepping_stone(pt) - Pigeons.stepping_stone(pt_enzyme)) < 1e-8

        # check that we actually used the buffered Enzyme implementation
        test_BufferedAD_usage(pt)
    end
end
