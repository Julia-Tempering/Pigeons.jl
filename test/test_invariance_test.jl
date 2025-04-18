using HypothesisTests

@testset "Explorer invariance test for TuringLogPotentials" begin
    # cannot use the one in Pigeons because conditioning does not work when the 
    # observation is an argument
    DynamicPPL.@model function product_of_probs(n_trials)
        p1 ~ Uniform()
        p2 ~ Uniform()
        n_successes ~ Binomial(n_trials, p1*p2)
        return n_successes
    end

    model = product_of_probs(100)
    target = TuringLogPotential(model)
    rng = SplittableRandom(1)

    @testset "Test a true negative" begin
        struct IdentityExplorer end

        function Pigeons.step!(::IdentityExplorer, replica, shared)
        end

        res = Pigeons.invariance_test(target, IdentityExplorer(), rng; condition_on=(:n_successes,))
        @test res.passed
    end

    @testset "Test a true positive" begin
        struct BadExplorer end
        function Pigeons.step!(::BadExplorer, replica, shared)
            Pigeons.update_state!(replica.state, :p1, 1, randn(replica.rng))
            Pigeons.update_state!(replica.state, :p2, 1, randn(replica.rng))
            return
        end
        res = Pigeons.invariance_test(target, BadExplorer(), rng;condition_on=(:n_successes,))
        @test !res.passed
        @test res.failed_tests == [1,2]
    end

    @testset "Invariance test for Pigeons' explorers" begin
        explorers = (
            SliceSampler(n_passes=50),
            AAPS(),
            MALA(base_n_refresh=50),
            AutoMALA(base_n_refresh=50, preconditioner=Pigeons.IdentityPreconditioner()),
            AutoMALA(base_n_refresh=50, estimated_target_std_deviations=[1.5, 1.5]) # simulate a round-based adaptation
        )
        for explorer in explorers
            @show explorer
            res = Pigeons.invariance_test(target, explorer, rng; condition_on=(:n_successes,)) 
            @show res.pvalues
            @test res.passed
        end
    end

    @testset "Check the no-conditioning case" begin
        DynamicPPL.@model function iid_mod()
            x ~ Beta()
            y ~ Gamma()
        end
        res = Pigeons.invariance_test(
            TuringLogPotential(iid_mod()), SliceSampler(), rng
        )
        @show res.pvalues
        @test res.passed
    end
end
