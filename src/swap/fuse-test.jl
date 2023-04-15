

# Black-box normal distribution
const gauss_dim = 1
create_explorer(::Distribution, ::Inputs) = SliceSampler(n_passes = 3)
create_reference_log_potential(::Distribution, ::Inputs) = Product(Normal.(zeros(gauss_dim), ones(gauss_dim)))
sample_iid!(distribution::Distribution, replica) = 
    rand!(replica.rng, distribution, replica.state)
create_state_initializer(my_potential::Distribution, ::Inputs) = my_potential
initialization(distribution::Distribution, ::SplittableRandom, ::Int) = zeros(length(distribution))

# Analytic exponential dist 
struct ExpDist 
    rate::Float64
end 
struct ExpSampler end
(dist::ExpDist)(x) = log(dist.rate) - dist.rate * x[1]
create_explorer(::ExpDist, ::Inputs) = ExpSampler() 
sample(rate, rng) = -log(rand(rng))/rate
function step!(::ExpSampler, replica, shared) 
    potential = find_log_potential(replica, shared) 
    rate =   potential.beta  * potential.path.target.rate + 
      (1.0 - potential.beta) * potential.path.ref.rate
    replica.state[1] = sample(rate, replica.rng) 
end
create_reference_log_potential(::ExpDist, ::Inputs) = ExpDist(1.0)
function sample_iid!(dist::ExpDist, replica)
    replica.state[1] = sample(dist.rate, replica.rng)
end
explorer_recorder_builders(::ExpSampler) = []
adapt_explorer(sampler::ExpSampler, _, _) = sampler
create_state_initializer(dist::ExpDist, ::Inputs) = dist
initialization(dist::ExpDist, rng::SplittableRandom, ::Int) = [sample(dist.rate, rng)]


