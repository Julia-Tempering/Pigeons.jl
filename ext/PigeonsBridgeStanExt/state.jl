
Pigeons.continuous_variables(state::StanState) = Pigeons.SINGLETON_VAR # all Stan variables should be continuous
Pigeons.discrete_variables(state::StanState) = []

Pigeons.extract_sample(state::StanState, log_potential) =
    BridgeStan.param_constrain(Pigeons.stan_model(log_potential), state.unconstrained_parameters)

function Pigeons.update_state!(state::StanState, name::Symbol, index, value)
    @assert name === :singleton_variable
    state.unconstrained_parameters[index] = value
end

function Pigeons.variable(state::StanState, name::Symbol)
    if name === :singleton_variable
        state.unconstrained_parameters
    else
        error()
    end
end

Pigeons.step!(explorer::AutoMALA, replica, shared, state::StanState) =
Pigeons.step!(explorer, replica, shared, state.unconstrained_parameters)

step!(explorer::Pigeons.HamiltonianSampler, replica, shared, state::StanState) =
    step!(explorer, replica, shared, state.unconstrained_parameters)



Pigeons.variable_names(::StanState, log_potential) = BridgeStan.param_names(Pigeons.stan_model(log_potential))

function Pigeons.slice_sample!(h::SliceSampler, state::StanState, log_potential, cached_lp, replica)
    cached_lp = Pigeons.cached_log_potential(log_potential, state, cached_lp)
    for i in eachindex(state.unconstrained_parameters)
        pointer = Ref(state.unconstrained_parameters, i)
        cached_lp = Pigeons.slice_sample_coord!(h, replica, pointer, log_potential, cached_lp)
    end
    return cached_lp
end

Base.:(==)(a::StanLogPotential, b::StanLogPotential) =
    a.data == b.data && BridgeStan.name(a.model) == BridgeStan.name(b.model)

Base.:(==)(a::StanState, b::StanState) = Pigeons.recursive_equal(a, b)

(log_potential::Pigeons.ScaledPrecisionNormalLogPotential)(x::StanState) = log_potential(x.unconstrained_parameters)
Random.rand!(rng::AbstractRNG, state::StanState{Vector{Float64}}, log_potential::Pigeons.ScaledPrecisionNormalLogPotential) =
    rand!(rng, state.unconstrained_parameters, log_potential)
