using DynamicPPL 
using Distributions
using Pigeons

@model function coinflip_unidentifiable(y)
    p1 ~ Uniform(0, 1)
    p2 ~ Uniform(0, 1)
    y .~ Bernoulli(p1*p2)
    return y
end;

function flip_model_unidentifiable()
    p_true = 0.5;
    N = 100;
    data = rand(Bernoulli(p_true), N);
    return coinflip_unidentifiable(data)
end

model = flip_model_unidentifiable()
pt = pigeons(target = TuringLogPotential(model), fused_swaps = true);

nothing