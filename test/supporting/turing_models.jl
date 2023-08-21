using DynamicPPL

# note: the models here don't use `filldist` in order to avoid importing
# Turing, which was crashing as of 2023-03-06
# Unconditioned coinflip model with `N` observations.
@model function coinflip(y)
    p ~ Beta(1, 12)
    y .~ Bernoulli(p)
    return y
end;

# *Unidentifiable* unconditioned coinflip model with `N` observations.
@model function coinflip_unidentifiable(y)
    p1 ~ Uniform(0, 1)
    p2 ~ Uniform(0, 1)
    y .~ Bernoulli(p1*p2)
    return y
end;

@model function coinflip_modified(y)
    p ~ Uniform(0.3, 0.7)
    # δ ~ Bernoulli(0.5)
    δ ~ DiscreteUniform(0, 2)
    y .~ Bernoulli(p + 0.1*δ)
    return y
end;

@model function coinflip_mixture(y)
    p1 ~ Uniform(0, 1)
    p2 ~ Uniform(0, 1)
    z ~ Bernoulli(0.2)
    y .~ Bernoulli(z == 0 ? p1 : p2)
    return y
end;


function flip_model()
    p_true = 0.5;
    N = 100;
    data = rand(Bernoulli(p_true), N);
    return coinflip(data)
end

function flip_model_unidentifiable()
    p_true = 0.5;
    N = 100;
    data = rand(Distributions.MersenneTwister(1), Bernoulli(p_true), N);
    return coinflip_unidentifiable(data)
end

function flip_model_modified()
    p_true = 0.5;
    N = 100;
    data = rand(Bernoulli(p_true), N);
    return coinflip_modified(data)
end

function flip_mixture() 
    p_true = 0.5;
    N = 100;
    data = rand(Bernoulli(p_true), N);
    return coinflip_mixture(data)
end

@model function turing_normal()
    x ~ Normal(0, 1)
end

DynamicPPL.@model function model_with_vectors()
    x ~ MvNormal(zeros(2), I)
    y ~ MvNormal(zeros(2), I)
end