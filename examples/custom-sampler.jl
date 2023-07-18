using IsingModels 
import IsingModels.IsingArray

struct IsingLogPotential 
    beta::Float64
    array_side_length::Int # number of binary variables = array_side_length^2
end

(log_potential::IsingLogPotential)(x::IsingArray) = -log_potential.beta * IsingModels.magnetization(x)

# Reference distribution uses beta = 0...
Pigeons.create_reference_log_potential(lp::IsingLogPotential, ::Inputs) = IsingLogPotential(0.0, lp.array_side_length)
# ... so that we can do i.i.d. sampling of Bernoullis at the reference:
function Pigeons.sample_iid!(reference_log_potential::IsingLogPotential, replica, shared)
    @assert reference_log_potential.beta == 0.0
    replica.state .= bitrand(replica.rng, reference_log_potential.array_side_length, reference_log_potential.array_side_length)
end

# Initialization
Pigeons.create_state_initializer(my_potential::IsingLogPotential, ::Inputs) = my_potential
Pigeons.initialization(lp::IsingLogPotential, ::SplittableRandom, ::Int) = falses(lp.array_side_length, lp.array_side_length)

# create a unified API for IsingModels' MCMC algorithms
abstract type IsingExplorer end
struct Wolff <: IsingExplorer 
    n_steps::Int
end 
struct Metropolis <: IsingExplorer 
    n_steps::Int
end 
sample_ising!(explorer::Wolff, state::IsingArray, beta::Real) = 
    IsingModels.wolff!(state, beta; steps = explorer.n_steps, save_interval = explorer.n_steps)
sample_ising!(explorer::Metropolis, state::IsingArray, beta::Real) = 
    IsingModels.metropolis!(state, beta; steps = explorer.n_steps, save_interval = explorer.n_steps)

# connect the above interface to Pigeons' local MCMC explorer interface
function Pigeons.step!(explorer::IsingExplorer, replica, shared)
    log_potential = Pigeons.find_log_potential(replica, shared.tempering, shared)
    beta = log_potential.beta 
    # Note: IsingModels does not accept rng arguments unfortunately at the moment, 
    #       but for reference, the replica-specific rng is obtained as follows:
    # rng = replica.rng 
    sample_ising!(explorer, replica.state, beta) 
end

# by default, apply Wolff once and a pass of Metropolis between each proposed swap:
Pigeons.default_explorer(lp::IsingLogPotential) = Wolff(1)
    #Metropolis(lp.array_side_length^2)
    #Compose(Wolff(1), Metropolis(lp.array_side_length^2))

Random.seed!(42) # because IsingModel only supports global rngs...
pt = pigeons(
        target = IsingLogPotential(1.0, 5), 
        n_rounds = 16,
        recorder_builders = [round_trip])

# # sanity check: the local communication barrier has a peak near the predicted phase transition log(1+sqrt(2))/2
# using Plots
# plot(pt.shared.tempering.communication_barriers.localbarrier)