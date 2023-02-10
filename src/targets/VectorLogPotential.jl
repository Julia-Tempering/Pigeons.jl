@concrete struct VectorLogPotential
    """
    User-coded function for the target log potential that assumes the state is a single vector.
    """
    target_log_potential

    """
    User-coded function for the reference log potential that assumes the state is a single vector.
    """
    reference_log_potential

    """
    Can be called with rand(rng, reference) to obtain a sample from the prior.
    E.g., a Distribution.
    """
    reference

    only_reference::Bool
end

@provides target VectorLogPotential(target_log_potential, reference_log_potential, prior) = 
  VectorLogPotential(target_log_potential, reference_log_potential, prior, false)

(log_potential::VectorLogPotential)(x) = log_potential.target_log_potential(x)

create_state_initializer(target::VectorLogPotential, ::Inputs) = target
initialization(target::VectorLogPotential, rng::SplittableRandom, _::Int64) = 
  rand(rng, target.reference)

create_explorer(::VectorLogPotential, ::Inputs) = SliceSampler()

create_reference_log_potential(target::VectorLogPotential, ::Inputs) = 
    VectorLogPotential(target.target_log_potential, target.reference_log_potential, target.reference, true)

function sample_iid!(log_potential::VectorLogPotential, replica) 
    replica.state = initialization(log_potential, replica.rng, replica.replica_index)
end