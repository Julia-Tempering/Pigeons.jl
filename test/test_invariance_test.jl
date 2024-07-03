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
    explorers = (SliceSampler(n_passes=10), AutoMALA(base_n_refresh=10))
    for explorer in explorers
        @show explorer
        @test first(Pigeons.invariance_test(target, explorer, rng; condition_on=(:n_successes,)))
    end
end
