"""
The state held in each Parallel Tempering [`Replica`](@ref). 
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

    """
    $SIGNATURES
    Extract a flattened vector (i.e. concatenation of all variables, with discrete 
    ones converted to Float64) ready for post-processing. 

    If the state is transformed (e.g. for HMC), this will create a fresh vector 
    with an un-transformed (i.e. original parameterization) state in it.

    When no transformations are needed, a copy should be created 
    (this is the default behaviour). 
    """
    extract_sample(state, log_potential) = copy(state)

    """ 
    $SIGNATURES 
    
    A list of string labels for the flattened vectors returned by 
    [`extract_sample()`](@ref).
    """
    variable_names(state, log_potential) = @abstract
end

function variable_names(pt::PT) 
    a_replica = locals(pt.replicas)[1]
    return variable_names(a_replica.state, find_log_potential(a_replica, pt.shared.tempering, pt.shared))
end

# Implementations
const SINGLETON_VAR = [:singleton_variable]

continuous_variables(state::Union{Nothing, StreamState}) = SINGLETON_VAR # e.g. for TestSwapper
discrete_variables(state::Union{Nothing, StreamState}) = []

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

variable_names(state::Array, log_potential) = map(i -> "param_$i", 1:length(state))


# For the stream interface, view the state as a black box
# and also we don't want that running with default block of recorders 
# crashes. 
continuous_variables(state::StreamState) = []
variable_names(state::StreamState) = []


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

function extract_sample(state::DynamicPPL.TypedVarInfo, log_potential)
    DynamicPPL.invlink!!(state, turing_model(log_potential))
    result = DynamicPPL.getall(state)
    DynamicPPL.link!!(state, DynamicPPL.SampleFromPrior(), turing_model(log_potential))
    return result
end

function variable_names(state::DynamicPPL.TypedVarInfo, _) 
    result = Symbol[] 
    all_names = fieldnames(typeof(state.metadata)) 
    for var_name in all_names
        var = state.metadata[var_name].vals
        if var isa Number || (var isa Array && length(var) == 1)
            push!(result, var_name) 
        elseif var isa Array
            # flatten vector names following Turing convention
            l = length(var) 
            for i in 1:l 
                var_and_index_name = 
                    Symbol(var_name, "[", join(ind2sub(size(var), i), ","), "]")
                push!(result, var_and_index_name)
            end
        else
            error()
        end
    end
    return result 
end
# From Turing.jl/src/utilities/helper.jl
ind2sub(v, i) = Tuple(CartesianIndices(v)[i])


# Stan ----------
"""
A state for stan target. 
Holds a vector in BridgeStan's unconstrained parameterization.
"""
@concrete mutable struct StanState 
    unconstrained_parameters
end

continuous_variables(state::StanState) = SINGLETON_VAR # all Stan variables should be continuous 
discrete_variables(state::StanState) = []

extract_sample(state::StanState, log_potential) = 
    BridgeStan.param_constrain(stan_model(log_potential), state.unconstrained_parameters)

function update_state!(state::StanState, name::Symbol, index, value) 
    @assert name === :singleton_variable
    state.unconstrained_parameters[index] = value
end

function variable(state::StanState, name::Symbol)
    if name === :singleton_variable
        state.unconstrained_parameters
    else
        error()
    end
end

variable_names(::StanState, log_potential) = BridgeStan.param_names(stan_model(log_potential))

