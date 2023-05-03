
using Pigeons
import Pigeons.HetPrecisionNormalLogPotential
using SplittableRandoms

const dim = 2

iso() = HetPrecisionNormalLogPotential(dim)

Pigeons.create_reference_log_potential(
    target::HetPrecisionNormalLogPotential, ::Inputs) = 
        target

Pigeons.create_state_initializer(my_potential::HetPrecisionNormalLogPotential, ::Inputs) = my_potential
Pigeons.initialization(::HetPrecisionNormalLogPotential, ::SplittableRandom, ::Int) = zeros(dim)
    
function Pigeons.sample_iid!(my_potential::HetPrecisionNormalLogPotential, replica)
    d = length(replica.state)
    @assert d == length(my_potential.precisions)
    for i in 1:d 
        replica.state[i] = randn(replica.rng) / sqrt(my_potential.precisions[i])
    end
end

# 2d iso: 0.997 on HMC(0.2, 1.0, 3)
pigeons(target = iso(), explorer = HMC(0.2, 1.0, 3, nothing, nothing, nothing), n_chains = 2, n_rounds = 10, recorder_builders = Pigeons.online_recorder_builders())



# ill-conditioned: 0.869 
bad_target = HetPrecisionNormalLogPotential([50.0, 1.0])
pigeons(target = bad_target, explorer = HMC(0.2, 1.0, 3, nothing, nothing, nothing), n_chains = 2, n_rounds = 10, recorder_builders = Pigeons.online_recorder_builders())


# now using the pre-conditioning
std_devs = 1.0 ./ sqrt.(bad_target.precisions)
pigeons(target = bad_target, explorer = HMC(0.2, 1.0, 3, std_devs, nothing, nothing), n_chains = 2, n_rounds = 10, recorder_builders = Pigeons.online_recorder_builders())
