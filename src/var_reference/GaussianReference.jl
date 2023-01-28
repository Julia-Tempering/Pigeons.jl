@concrete struct GaussianReference <: VarReference
    d
    μ
    Σ
end

function update_var_reference!(::GaussianReference, path)
    0
end

var_reference_recorder_builders(::GaussianReference) = [] # todo