"""
The state held in each Parallel Tempering [`Replica`](@ref). 
This interface is only needed for variational Parallel Tempering and for 
some recorders such as [`OnlineStateRecorder`](@ref).
(Note that, at the moment, explorers automatically detect the variable type 
and dispatch accordingly.)
"""
@informal state begin
    """ 
    $SIGNATURES 
    The names (each a `Symbol`) of the continuous variables in the given [`state`](@ref). 
    """
    continuous_variables(state) = @abstract 

    """ 
    $SIGNATURES 
    The names (each a `Symbol`) of the discrete (Int) variables in the given state. 
    """
    discrete_variables(state) = @abstract 

    """
    $SIGNATURES 
    The storage within the [`state`](@ref) of the variable of the given name, typically an `Array`.
    """
    variable(state, name::Symbol) = @abstract 

    """
    $SIGNATURES
    Update the state's entry at symbol `name` and `index` with `value`.
    """
    update_state!(state, name::Symbol, index, value) = @abstract
end


# Implementations
const SINGLETON_VAR = [:singleton_variable]

continuous_variables(state::Union{Nothing, Pigeons.StreamState}) = SINGLETON_VAR # e.g. for TestSwapper
discrete_variables(state::Union{Nothing, Pigeons.StreamState}) = []

continuous_variables(state::Array) = SINGLETON_VAR
discrete_variables(state::Array) = []

function update_state!(state::Array, name::Symbol, index, value) 
    @assert name === :singleton_variable
    state[index] = value
end

function variable(state::Array, name::Symbol)
    if name === :singleton_variable
        state
    else
        error()
    end
end


# For the stream interface, view the state as a black box
# and also we don't want that running with default block of recorders 
# crashes. 
continuous_variables(state::StreamState) = []


# DynamicPPL ----------
continuous_variables(state::DynamicPPL.TypedVarInfo) = variables(state::DynamicPPL.TypedVarInfo, AbstractFloat)
discrete_variables(state::DynamicPPL.TypedVarInfo) = variables(state::DynamicPPL.TypedVarInfo, Integer)
variable(state::DynamicPPL.TypedVarInfo, name::Symbol) = state.metadata[name].vals
function update_state!(state::DynamicPPL.TypedVarInfo, name::Symbol, index::Int, value)
    state.metadata[name].vals[index] = value
end
function variables(state::DynamicPPL.TypedVarInfo, type::DataType) 
    all_names = fieldnames(typeof(state.metadata))
    var_names = []
    for name in all_names
        if typeof(state.metadata[name].vals[1]) <: type
            var_names = vcat(var_names, name)
        end
    end
    return var_names
end

function on_transformed_space(sampling_task, state::DynamicPPL.TypedVarInfo, log_potential)
    transform_back = false
    if !DynamicPPL.istrans(state, DynamicPPL._getvns(state, DynamicPPL.SampleFromPrior())[1]) # check if in constrained space
        DynamicPPL.link!!(state, DynamicPPL.SampleFromPrior(), turing_model(log_potential)) # transform to unconstrained space
        transform_back = true # transform it back after log_potential evaluation
    end
    ret = sampling_task()
    if transform_back
        DynamicPPL.invlink!!(state, turing_model(log_potential)) # transform back to constrained space
    end
    return ret
end
# end DynamicPPL ----------


# Stan ----------
@concrete mutable struct StanState 
    x # vector of constrained or unconstrained parameters
    constrained::Bool
end

continuous_variables(state::StanState) = SINGLETON_VAR # all Stan variables should be continuous 
discrete_variables(state::StanState) = []

function on_transformed_space(sampling_task, state::StanState, log_potential)
    transform_back = false
    if state.constrained
        BridgeStan.param_unconstrain!(stan_model(log_potential), state.x, state.x)
        state.constrained = false
        transform_back = true 
    end
    ret = sampling_task()
    if transform_back
        BridgeStan.param_constrain!(stan_model(log_potential), state.x, state.x)
        state.constrained = true
    end
    return ret
end
# end Stan ----------

