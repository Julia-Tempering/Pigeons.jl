@concrete struct StanLogPotential
    model
    initialization_std
end

stan_model(log_potential::StanLogPotential) = log_potential.model 
stan_model(log_potential::InterpolatedLogPotential) = log_potential.path.target.model

"""
Evaluate the log potential at a given point `x` of type `StanState`.
"""
function (log_potential::StanLogPotential)(state::StanState)
    on_transformed_space(state, log_potential) do # convert to unconstrained (transformed) space  
        BridgeStan.log_density(log_potential.model, state.x; propto = true, jacobian = true)
    end
end

"""
$SIGNATURES 
Given a `StanModel` from BridgeStan, create a 
`StanLogPotential` conforming to both [`target`](@ref) and [`log_potential`](@ref).
"""
@provides target StanLogPotential(model::BridgeStan.StanModel) = 
    StanLogPotential(model, 1e1) # TODO: find a good default

create_state_initializer(target::StanLogPotential, ::Inputs) = target  
function initialization(target::StanLogPotential, rng::SplittableRandom, _::Int64)
    d_unc = BridgeStan.param_unc_num(target.model) # number of unconstrained parameters 
    init_unc = randn(rng, d_unc) * target.initialization_std
    init = BridgeStan.param_constrain(target.model, init_unc)
    return StanState(init, true)
end

create_explorer(::StanLogPotential, ::Inputs) = SliceSampler()

create_reference_log_potential(target::StanLogPotential, ::Inputs) = 
    StanLogPotential(target.model) # set reference = target for first few tuning rounds

function sample_iid!(log_potential::StanLogPotential, replica, shared) 
    # it doesn't seem possible to obtain iid samples from the prior with BridgeStan 
    # default to slicer as the explorer in the reference
    step!(SliceSampler(), replica, shared)
end