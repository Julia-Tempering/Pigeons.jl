DynamicPPL.@model function toy_turing_model(y)
    p1 ~ Uniform(0, 1)
    p2 ~ Uniform(0, 1)
    y .~ Bernoulli(p1*p2)
    return y
end;

""" 
$SIGNATURES 

A toy Turing model used for testing (unidentifiable 2-dim params for a bernoulli). 
"""
@provides target function toy_turing_target()
    p_true = 0.5;
    N = 1;
    data = rand(Bernoulli(p_true), N);
    return TuringLogPotential(toy_turing_model(data))
end