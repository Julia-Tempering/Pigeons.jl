

#=
    - framework to test T-swaps
    - test gradient
=#


using Pigeons
using SplittableRandoms
using Distributions

using ForwardDiff: ForwardDiff
using Turing
using DynamicPPL

using LogDensityProblemsAD

@model function coinflip(y)
    p ~ Beta(1, 12)
    y .~ Bernoulli(p)
    return y
end;

function flip_model()
    p_true = 0.5;
    N = 100;
    data = rand(Bernoulli(p_true), N);
    return coinflip(data)
end

rng = SplittableRandom(1)

fct = LogDensityFunction(flip_model());

g = ADgradient(:ForwardDiff, fct)

LogDensityProblemsAD.logdensity_and_gradient(g, [0.01]);

#s = Pigeons.initialization(TuringLogPotential(flip_model()), rng,  0)

