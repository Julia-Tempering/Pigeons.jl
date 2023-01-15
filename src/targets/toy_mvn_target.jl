""" 
$SIGNATURES 

A toy multi-variate normal (mvn) target distribution used for testing. 
Uses a specialized path, [`ScaledPrecisionNormalPath`](@ref), 
such that i.i.d. sampling is possible at all chains (via [`ToyExplorer`](@ref)). 
"""
@provides target toy_mvn_target(dim::Int) = ScaledPrecisionNormalPath(dim) 

create_state_initializer(target::ScaledPrecisionNormalPath, ::Inputs) = 
    Ref(zeros(target.dim))  

create_explorer(::ScaledPrecisionNormalPath, ::Inputs) = 
    ToyExplorer()

function sample_iid!(log_potential::MultivariateNormal, replica) 
    replica.state = rand(replica.rng, log_potential)
end

create_path(target::MultivariateNormal, ::Inputs) = 
    target # a bit of a special case here: the target is also a path