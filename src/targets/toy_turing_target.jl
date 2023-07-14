DynamicPPL.@model function toy_turing_model(dim::Int, precision)
    y = Vector{Float64}(undef, dim)
    for i in 1:dim 
        y[i] ~ Normal(0.0, 1.0 / sqrt(precision))
    end
    return y
end

function toy_turing_target(dim::Int, precision = 10.0)
    return TuringLogPotential(toy_turing_model(dim, precision))
end

DynamicPPL.@model function toy_turing_unid_model(number, sum)
    p1 ~ Uniform(0, 1)
    p2 ~ Uniform(0, 1)
    sum ~ Binomial(number, p1*p2)
    return sum
end

""" 
$SIGNATURES 

A toy Turing model used for testing (unidentifiable 2-dim params for a bernoulli). 
"""
@provides target function toy_turing_unid_target(number = 100000, sum = ceil(Int, number/2))
    return TuringLogPotential(toy_turing_unid_model(number, sum))
end