"""
Supports user-defined real-valued log potentials that take in vectors as input.
"""
@concrete struct VectorLogPotential
    """
    User-coded function for the target log potential that assumes the state is a vector.
    """
    target_log_potential

    """
    User-coded function for the reference log potential that assumes the state is a vector.
    """
    reference_log_potential

    """
    E.g., reference_sample!(rng, state) yields a sample from the reference,
    modifying the vector `state`.
    """
    reference_sample!

    """
    The starting state that will be used to initialize the PT Markov chain on the expanded space. 
    """
    initial_state

    """
    Whether to only use the prior to evaluate the log potential (i.e., evaluate the prior log density).
    """
    only_reference::Bool
end

@provides target VectorLogPotential(target_log_potential, reference_log_potential, reference_sample!, initial_state) = 
  VectorLogPotential(target_log_potential, reference_log_potential, reference_sample!, initial_state, false)

dim(log_potential::VectorLogPotential) = length(log_potential.initial_state)

function (log_potential::VectorLogPotential)(x)
  log_potential.only_reference ? log_potential.reference_log_potential(x) : 
    log_potential.target_log_potential(x)
end

create_state_initializer(target::VectorLogPotential, ::Inputs) = target
initialization(target::VectorLogPotential, rng::SplittableRandom, _::Int64) = 
  copy(target.initial_state)

create_explorer(::VectorLogPotential, ::Inputs) = SliceSampler()

create_reference_log_potential(target::VectorLogPotential, ::Inputs) = 
  VectorLogPotential(target.target_log_potential, target.reference_log_potential, 
                     target.reference_sample!, target.initial_state, true)

sample_iid!(target::VectorLogPotential, replica) = 
  target.reference_sample!(replica.rng, replica.state)