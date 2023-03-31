

#=
    - framework to test T-swaps
    - test gradient
=#


#using Pigeons
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

@model function discr(y)
    p1 ~ Beta(1, 12)
    p2 ~ Beta(1, 1)
    indic ~ Bernoulli(0.5)
    y .~ Bernoulli(p1)
    return y
end;

@model function gdemo(x, y)
    s² ~ InverseGamma(2, 3)
    m ~ Normal(0, sqrt(s²))
    x ~ Normal(m, sqrt(s²))
    y ~ Normal(m, sqrt(s²))
    #indic ~ Bernoulli(0.5)
end

@model function model_function(y)
    s ~ Poisson(1)
    y ~ Normal(s, 1)
    return y
end

function flip_model(is_disc = false)
    p_true = 0.5;
    N = 100;
    data = rand(Bernoulli(p_true), N);
    return is_disc ? discr(data) : coinflip(data)
end

rng = SplittableRandom(1)
is_disc = false

param = is_disc ? [0.01, 0.02] : [0.01]

fct = LogDensityFunction(flip_model(is_disc));

g = ADgradient(:ForwardDiff, fct)

println(LogDensityProblemsAD.logdensity_and_gradient(g, param));

# test with prior

vi = DynamicPPL.VarInfo(rng, flip_model(is_disc))

prior_fct = LogDensityFunction(vi, flip_model(is_disc), DynamicPPL.PriorContext())


prior_g = ADgradient(:ForwardDiff, prior_fct)

LogDensityProblemsAD.logdensity_and_gradient(prior_g, param)

println(LogDensityProblemsAD.logdensity_and_gradient(prior_g, param));



#= 

TODO: not clear how to compute gradient on the prior, but could 
just resort to having the 2 end points 

=#

#s = Pigeons.initialization(TuringLogPotential(flip_model()), rng,  0)
