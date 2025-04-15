
DynamicPPL.@model function toy_beta_binom_model(n_trials, n_successes)
    p ~ Uniform(0, 1)
    n_successes ~ Binomial(n_trials, p)
    return n_successes
end

function toy_beta_binom_target(n_trials = 10, n_successes = 2)
    return Pigeons.TuringLogPotential(toy_beta_binom_model(n_trials, n_successes))
end

const ToyBetaBinomType = typeof(toy_beta_binom_target())

function Pigeons.initialization(target::ToyBetaBinomType, rng::AbstractRNG, ::Int64) 
    result = DynamicPPL.VarInfo(rng, target.model, DynamicPPL.SampleFromPrior(), DynamicPPL.PriorContext())
    DynamicPPL.link(result, target.model)

    # custom init goes here: for example here setting the variable p to 0.5
    Pigeons.update_state!(result, :p, 1, 0.5)

    return result
end

@testset "Test Turing Init" begin
    pt = pigeons(target = toy_beta_binom_target(), n_rounds = 0)
    @test Pigeons.variable(pt.replicas[1].state, :p) == [0.5]
end