struct NoVarReference <: VarReference end 

activate_var_reference(::NoVarReference, _) = false
update_path!(path, _, ::NoVarReference) = nothing
var_reference_recorder_builders(::NoVarReference) = []