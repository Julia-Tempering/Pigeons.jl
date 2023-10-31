DynamicPPL.@model function toy_turing_model(dim::Int, precision)
    y = Vector{Float64}(undef, dim)
    for i in 1:dim
        y[i] ~ Normal(0.0, 1.0 / sqrt(precision))
    end
    return y
end

function Pigeons.toy_turing_target(dim::Int, precision = 10.0)
    return Pigeons.TuringLogPotential(toy_turing_model(dim, precision))
end

DynamicPPL.@model function toy_turing_unid_model(n_trials, n_successes)
    p1 ~ Uniform(0, 1)
    p2 ~ Uniform(0, 1)
    n_successes ~ Binomial(n_trials, p1*p2)
    return n_successes
end

Pigeons.@provides target function Pigeons.toy_turing_unid_target(n_trials = 100000, n_successes = ceil(Int, n_trials/2))
    return Pigeons.TuringLogPotential(toy_turing_unid_model(n_trials, n_successes))
end
