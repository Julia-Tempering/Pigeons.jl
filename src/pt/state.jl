
""" 
$SIGNATURES 

The names (each a `Symbol`) of the continuous variables in the given state. 
"""
continuous_variables(state) = @abstract 

"""
$SIGNATURES 

The storage within the state of the variable of the given name, typically an `Array`.
"""
variable(state, name::Symbol) = @abstract 
