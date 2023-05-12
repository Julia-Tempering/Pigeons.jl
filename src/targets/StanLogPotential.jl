@concrete struct StanLogPotential
    model
    model_only_prior
    only_prior::Bool
end

stan_model(log_potential::StanLogPotential) = log_potential.model 
stan_model(log_potential::InterpolatedLogPotential) = log_potential.path.target.model

function (log_potential::StanLogPotential)(x)
    if log_potential.only_prior
        BridgeStan.log_density(log_potential.model_only_prior, x; propto = true, jacobian = true)
    else  
        BridgeStan.log_density(log_potential.model, x; propto = true, jacobian = true)
    end
end

"""
$SIGNATURES 
Given a `StanModel` from BridgeStan, create a 
`StanLogPotential` conforming to both [`target`](@ref) and [`log_potential`](@ref).
"""
@provides target StanLogPotential(model::BridgeStan.StanModel, model_only_prior::BridgeStan.StanModel) = 
    StanLogPotential(model, model_only_prior, false)
# TODO: at the moment, the user needs to input the "model/data" for the prior, as well.

create_state_initializer(target::StanLogPotential, ::Inputs) = target  
initialization(target::StanLogPotential, rng::SplittableRandom, _::Int64) = 
    @abstract # TODO # DynamicPPL.VarInfo(rng, target.model, DynamicPPL.SampleFromPrior(), DynamicPPL.PriorContext()) 

create_explorer(::StanLogPotential, ::Inputs) = SliceSampler()

create_reference_log_potential(target::StanLogPotential, ::Inputs) = 
    StanLogPotential(target.model, target.model_only_prior, true)

function sample_iid!(log_potential::StanLogPotential, replica) 
    replica.state = initialization(log_potential, replica.rng, replica.replica_index)
end