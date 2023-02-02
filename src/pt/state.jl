""" 
The state held in each Parallel Tempering [`Replica`](@ref). 
This interface is only needed for variation Parallel Tempering and for 
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

    The storage within the [`state`](@ref) of the variable of the given name, typically an `Array`.
    """
    variable(state, name::Symbol) = @abstract 
end