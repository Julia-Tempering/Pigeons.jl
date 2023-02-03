@concrete struct GaussianReference <: VarReference
    d
    μ
    Σ
end

function update_var_reference!(path, iterators::Iterators, ::GaussianReference)
    0
end

var_reference_recorder_builders(::GaussianReference) = [] # todo