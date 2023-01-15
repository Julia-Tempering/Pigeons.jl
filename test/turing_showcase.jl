using Pigeons
using Turing

# Unconditioned coinflip model with `N` observations.
@model function coinflip(; N::Int)
    # Our prior belief about the probability of heads in a coin toss.
    p ~ Beta(1, 12)
    # Heads or tails of a coin are drawn from `N` independent and identically
    # distributed Bernoulli distributions with success rate `p`.
    y ~ filldist(Bernoulli(p), N)
    return y
end;
coinflip(y::AbstractVector{<:Real}) = coinflip(; N=length(y)) | (; y)

function flip_model()
    p_true = 0.5;
    N = 100;
    data = rand(Bernoulli(p_true), N);
    return coinflip(data) # was coinflip(data)
end

model = flip_model()
pigeons(target = Pigeons.TuringLogPotential(model), checked_round = 3)