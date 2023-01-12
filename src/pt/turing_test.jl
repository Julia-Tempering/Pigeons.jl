using Turing
using Random



using LinearAlgebra

rng = MersenneTwister(1)

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


@model function gaussian_mixture_model(x)
    # Draw the parameters for each of the K=2 clusters from a standard normal distribution.
    K = 2
    μ ~ MvNormal(Zeros(K), I)

    # Draw the weights for the K clusters from a Dirichlet distribution with parameters αₖ = 1.
    w ~ Dirichlet(K, 1.0)
    # Alternatively, one could use a fixed set of weights.
    # w = fill(1/K, K)

    # Construct categorical distribution of assignments.
    distribution_assignments = Categorical(w)

    # Construct multivariate normal distributions of each cluster.
    D, N = size(x)
    distribution_clusters = [MvNormal(Fill(μₖ, D), I) for μₖ in μ]

    # Draw assignments for each datum and generate it from the multivariate normal distribution.
    k = Vector{Int}(undef, N)
    for i in 1:N
        k[i] ~ distribution_assignments
        x[:, i] ~ distribution_clusters[k[i]]
    end

    return k
end


function mix_model()

    # Set a random seed.
    Random.seed!(3)

    # Define Gaussian mixture model.
    w = [0.5, 0.5]
    μ = [-3.5, 0.5]
    mixturemodel = MixtureModel([MvNormal(Fill(μₖ, 2), I) for μₖ in μ], w)

    # We draw the data points.
    N = 60
    x = rand(mixturemodel, N);

    return gaussian_mixture_model(x);
end

function flip_model()
    p_true = 0.5;

    N = 100;

    data = rand(Bernoulli(p_true), N);

    return coinflip(data)
end


# magic lines for Turing

# creating model:



model = flip_model() # mix_model() #


vi = DynamicPPL.VarInfo(rng, model, DynamicPPL.SampleFromPrior(), DynamicPPL.PriorContext()) 
DynamicPPL.link!(vi, DynamicPPL.SampleFromPrior())
#println("sampled from prior: $(vi.metadata.p)") 

println("logprior: $(logprior(model, vi))")
println("loglikelihood: $(loglikelihood(model, vi))")

vi.metadata.p.vals[1] = -2

println("logprior: $(logprior(model, vi))")
println("loglikelihood: $(loglikelihood(model, vi))")

DPPL.invlink!(vi, tm.spl)
