
Pigeons.continuous_variables(::Pigeons.StanState) = Pigeons.SINGLETON_VAR # all Stan variables should be continuous
Pigeons.discrete_variables(::Pigeons.StanState) = []

Pigeons.extract_sample(state::Pigeons.StanState, log_potential) =
    [
        BridgeStan.param_constrain(Pigeons.stan_model(log_potential), state.unconstrained_parameters; include_tp = true, include_gq = true, rng = state.rng);
        log_potential(state)
    ]


function Pigeons.update_state!(state::Pigeons.StanState, name::Symbol, index, value)
    @assert name === :singleton_variable
    state.unconstrained_parameters[index] = value
end

function Pigeons.variable(state::Pigeons.StanState, name::Symbol)
    if name === :singleton_variable
        state.unconstrained_parameters
    else
        error()
    end
end

Pigeons.sample_names(::Pigeons.StanState, log_potential) = 
    [
        BridgeStan.param_names(Pigeons.stan_model(log_potential); include_tp = true, include_gq = true);
        :log_density 
    ]

#=
specialized equality checks
=#
Pigeons.recursive_equal(a::StanLogPotential, b::StanLogPotential) =
    a.data == b.data && BridgeStan.name(a.model) == BridgeStan.name(b.model)
Pigeons.recursive_equal(a::StanRNG, b::StanRNG) = Pigeons._recursive_equal(a, b)

#=
explorer implementations
=#
Pigeons.slice_sample!(h::SliceSampler, state::Pigeons.StanState, args...) =
    Pigeons.slice_sample!(h, state.unconstrained_parameters, args...)
Pigeons.step!(explorer::Pigeons.HamiltonianSampler, replica, shared, state::Pigeons.StanState) =
    Pigeons.step!(explorer, replica, shared, state.unconstrained_parameters)

(log_potential::Pigeons.ScaledPrecisionNormalLogPotential)(x::Pigeons.StanState) = log_potential(x.unconstrained_parameters)
Random.rand!(rng::AbstractRNG, state::Pigeons.StanState{Vector{Float64}}, log_potential::Pigeons.ScaledPrecisionNormalLogPotential) =
    rand!(rng, state.unconstrained_parameters, log_potential)
