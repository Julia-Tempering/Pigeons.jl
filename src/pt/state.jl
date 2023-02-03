
""" 
$SIGNATURES 
The names (each a `Symbol`) of the continuous (Float) variables in the given state. 
"""
continuous_variables(state) = @abstract 

""" 
$SIGNATURES 
The names (each a `Symbol`) of the discrete (Int) variables in the given state. 
"""
discrete_variables(state) = @abstract 

"""
$SIGNATURES 
The storage within the state of the variable of the given name, typically an `Array`.
"""
variable(state, name::Symbol) = @abstract 


const CONTINUOUS_VARS = Ref([])
const DISCRETE_VARS = Ref([])