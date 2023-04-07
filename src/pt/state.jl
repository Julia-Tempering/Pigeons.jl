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


const CONTINUOUS_VARS = Ref([])
const DISCRETE_VARS = Ref([])


# Implementations
const SINGLETON_VAR = [:singleton_variable]

continuous_variables(state::Union{Nothing, Pigeons.StreamState}) = SINGLETON_VAR # e.g. for TestSwapper
discrete_variables(state::Union{Nothing, Pigeons.StreamState}) = []

continuous_variables(state::Array) = SINGLETON_VAR
discrete_variables(state::Array) = []
update_state!(state::Array, name::Symbol, index, value) = (state[name][index] = value)
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

