using Turing
using Random



# magic lines for Turing

# creating model:

p_true = 0.5;

N = 100;

data = rand(Bernoulli(p_true), N);

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

model = coinflip(data);


vi = DynamicPPL.VarInfo(rng, model, DynamicPPL.SampleFromPrior(), DynamicPPL.PriorContext()) 
println("sampled from prior: $(vi.metadata.p)") 

println("logprior: $(logprior(model, vi))")
println("loglikelihood: $(loglikelihood(model, vi))")

vi.metadata.p.vals[1] = 0.2

println("logprior: $(logprior(model, vi))")
println("loglikelihood: $(loglikelihood(model, vi))")
