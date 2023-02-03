"""
The state held in each Parallel Tempering [`Replica`](@ref). 
This interface is only needed for variational Parallel Tempering and for 
some recorders such as [`OnlineStateRecorder`](@ref).
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
end


const CONTINUOUS_VARS = Ref([])
const DISCRETE_VARS = Ref([])


# Implementations

const SINGLETON_VAR = [:singleton_variable]
continuous_variables(state::Array) = SINGLETON_VAR
variable(state::Array, name::Symbol) = 
    if name === :singleton_variable
        state 
    else
        error()
    end

# For the stream interface, view the state as a black box
# Useful so that running with default block of recorders 
# does not crash. 
continuous_variables(state::StreamState) = []


