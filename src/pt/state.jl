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
    Extract a sample for postprocessing. By default, calls `copy()` but many overloads are 
        defined for different kinds of states.
    
    Typically, this will be a flattened vector (i.e. concatenation of all variables, with discrete
    ones converted to Float64) ready for post-processing. 

    The corresponding un-normalized log density might be appended at the very end.

    If the state is transformed (e.g. for HMC), this will create a fresh vector
    with an un-transformed (i.e. original parameterization) state in it.
    """
    extract_sample(state, log_potential) = copy(state)

    """
    $SIGNATURES

    A list of string labels for the flattened vectors returned by
    [`extract_sample()`](@ref).

    The key `:log_density` is used when the un-normalized log density 
    is included.
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

extract_sample(state::Array, log_potential) = [state; log_potential(state)]

function variable(state::Array, name::Symbol)
    if name === :singleton_variable
        state
    else
        error()
    end
end

function variables end

variable_names(state::Array, log_potential) = [map(i -> Symbol("param_$i"), 1:length(state)); :log_density]


# For the stream interface, view the state as a black box
# and also we don't want that running with default block of recorders
# crashes.
continuous_variables(state::StreamState) = []
variable_names(state::StreamState) = []
