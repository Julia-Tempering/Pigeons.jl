using DynamicPPL
using AbstractMCMC

include("../target/JuliaBUGSLogPotential.jl")

struct JuliaBUGSGibbsSampler
end

mutable struct JuliaBUGSState
    gibbsState::JuliaBUGS.GibbsState
    param_vals::Vector{Any}
end

function Pigeons.initialization(target::JuliaBUGSLogPotential, rng::AbstractRNG, _::Int64)
    new_values, st = AbstractMCMC.step(
        rng,
        AbstractMCMC.LogDensityModel(target.model),
        JuliaBUGS.Gibbs(target.model, JuliaBUGS.MHFromPrior()),)    
    return JuliaBUGSState(st, new_values)
end

function Pigeons.step!(explorer::JuliaBUGSGibbsSampler, replica, shared, state::JuliaBUGSState)
    new_values, st = AbstractMCMC.step(
        replica.rng,
        AbstractMCMC.LogDensityModel(target.model),
        JuliaBUGS.Gibbs(target.model, JuliaBUGS.MHFromPrior()),
        state.gibbsState,)
    replica.state = JuliaBUGSState(st, new_values)
end

(log_potential::JuliaBUGSPotential)(x::JuliaBUGSState) = log_potential(x.param_vals)

Pigeons.extract_sample(state::JuliaBUGSState, log_potential) = state.param_vals
