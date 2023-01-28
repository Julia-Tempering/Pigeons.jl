struct NoVarReference <: VarReference end 

activate_var_reference(::NoVarReference, _) = false
var_reference_recorder_builders(::NoVarReference) = []
