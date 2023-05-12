using Pigeons
using Statistics
using SplittableRandoms
using Random 
using LogExpFunctions

struct MyLogPotential end
# bimodal target with 0.5*N(-100, 1) + 0.5*N(100, 1)
(::MyLogPotential)(x) = LogExpFunctions.logaddexp(
    -0.5*(x[1] + 100)^2 - 0.5*log(2*pi) + log(0.5), 
    -0.5*(x[1] - 100)^2 - 0.5*log(2*pi) + log(0.5))
Pigeons.create_explorer(::MyLogPotential, ::Inputs) = Pigeons.SliceSampler() 
Pigeons.create_state_initializer(my_potential::MyLogPotential, ::Inputs) = my_potential
Pigeons.initialization(::MyLogPotential, ::SplittableRandom, ::Int) = [0.0]

# create a custom reference
struct MyReferenceLogPotential end 
(::MyReferenceLogPotential)(x) = -1/(2*(100^2+1)) * (x[1])^2
# normal reference with mean 0 and standard deviation sqrt(100^2+1)
Pigeons.create_reference_log_potential(::MyLogPotential, ::Inputs) = MyReferenceLogPotential()
Pigeons.sample_iid!(log_potential::MyReferenceLogPotential, replica, shared) =
    rand!(replica.rng, replica.state, log_potential)
Random.rand!(rng::AbstractRNG, x::AbstractVector, log_potential::MyReferenceLogPotential) =
    for i in eachindex(x)
        x[i] = randn(rng) * sqrt(100^2 + 1)
    end

inputs = Inputs(
    target = MyLogPotential(), 
    recorder_builders = Pigeons.online_recorder_builders(),
    n_rounds = 15,
    n_chains = 30
)
pt = pigeons(inputs)
@show mean(pt), var(pt)
nothing