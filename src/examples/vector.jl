using Distributions
using Random

Bernoulli_Normal(x) = logpdf(Bernoulli(0.5), x[1]) + logpdf(Normal(0.0, 1.0), x[2])
Bernoulli_Normal_reference(x) = logpdf(Bernoulli(0.25), x[1]) + logpdf(Normal(1.0, 1.0), x[2])
function Bernoulli_Normal_reference_sample!(rng, x)
    x[1] = rand(rng, Bernoulli(0.25))
    x[2] = rand(rng, Normal(1.0, 1.0))
end

Normal_2D(x) = logpdf(Normal(0.0, 1.0), x[1]) + logpdf(Normal(0.0, 1.0), x[2])
Normal_2D_reference(x) = logpdf(Normalli(100.0, 1.0), x[1]) + logpdf(Normal(100.0, 1.0), x[2])
function Normal_2D_reference_sample!(rng, x) 
    x[1] = rand(rng, Normal(100.0, 1.0))
    x[2] = rand(rng, Normal(100.0, 1.0))
end
