using HypothesisTests

@testset "Explorer invariance test for TuringLogPotentials" begin
    # cannot use the one in Pigeons because conditioning does not work when the observation is an argument
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

        res = @test_logs (:info,"All invariance tests passed :)") begin
            Pigeons.invariance_test(target, IdentityExplorer(), rng; condition_on=(:n_successes,))
        end
        @test res.passed
        @test all(==(1), res.pvalues)
    end

    @testset "Test a true positive" begin
        struct BadExplorer end
        function Pigeons.step!(::BadExplorer, replica, shared)
            Pigeons.update_state!(replica.state, :p1, 1, randn(replica.rng))
            Pigeons.update_state!(replica.state, :p2, 1, randn(replica.rng))
            return
        end
        res = @test_logs (:warn,"Some invariance tests failed; inspect the output.") begin
            Pigeons.invariance_test(target, BadExplorer(), rng;condition_on=(:n_successes,))
        end
        @test !res.passed
        @test res.failed_tests == [1,2]
    end

    @testset "Invariance test for Pigeons' explorers" begin
        explorers = (
            SliceSampler(n_passes=10),
            AutoMALA(base_n_refresh=10, preconditioner=Pigeons.IdentityPreconditioner()),
            AutoMALA(base_n_refresh=10, estimated_target_std_deviations=[1.5, 1.5]) # simulate a round-based adaptation
        )
        for explorer in explorers
            @show explorer
            @test first(Pigeons.invariance_test(target, explorer, rng; condition_on=(:n_successes,)))
        end
    end
end
