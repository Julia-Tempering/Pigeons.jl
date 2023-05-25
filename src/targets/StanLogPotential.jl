@concrete struct StanLogPotential
    model
    model_only_prior
    only_prior::Bool
    initial_values
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
@provides target StanLogPotential(model::BridgeStan.StanModel, model_only_prior::BridgeStan.StanModel, initial_values) = 
    StanLogPotential(model, model_only_prior, false, initial_values)
# TODO: at the moment, the user needs to input the "model/data" for the prior, as well.

create_state_initializer(target::StanLogPotential, ::Inputs) = target  
initialization(target::StanLogPotential, rng::SplittableRandom, _::Int64) = 
    copy(target.initial_values) # TODO: make this cleaner 

create_explorer(::StanLogPotential, ::Inputs) = SliceSampler()

create_reference_log_potential(target::StanLogPotential, ::Inputs) = 
    StanLogPotential(target.model, target.model_only_prior, true, target.initial_values)

function sample_iid!(log_potential::StanLogPotential, replica, shared) 
    # TODO: at the moment it's not clear how to obtain iid samples from the prior with BridgeStan 
    # default to slicer as the explorer in the reference
    step!(SliceSampler(), replica, shared)
end