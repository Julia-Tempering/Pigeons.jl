"""
A Gaussian mean-field variational reference (i.e., with a diagonal covariance matrix).
"""
@concrete struct GaussianReference <: VarReference
    μ::Vector # means
    σ::Vector # standard deviations
end

dim(var_reference::GaussianReference) = length(var_reference.μ)
activate_var_reference(::GaussianReference, iterators::Iterators) = iterators.round ≥ 6 ? true : false
var_reference_recorder_builders(::GaussianReference) = [target_online]


update_path!(path, iterators, ::GaussianReference) = @abstract # TODO
sample_iid!(::GaussianReference) = @abstract # TODO