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
    Number of model parameters. 
    """
    dim # TODO: remove

    only_reference::Bool
end

@provides target VectorLogPotential(target_log_potential, reference_log_potential, reference_sample!, dim) = 
  VectorLogPotential(target_log_potential, reference_log_potential, reference_sample!, dim, false)

function (log_potential::VectorLogPotential)(x)
  log_potential.only_reference ? log_potential.reference_log_potential(x) : 
    log_potential.target_log_potential(x)
end

"""
An *allocating* version of reference_sample!() that does not need to accept a `state`.
"""
function reference_sample(rng, target::VectorLogPotential) 
    state = Vector{Number}(undef, target.dim)
    target.reference_sample!(rng, state)
    return state
end

create_state_initializer(target::VectorLogPotential, ::Inputs) = target
initialization(target::VectorLogPotential, rng::SplittableRandom, _::Int64) = 
  reference_sample(rng, target)

create_explorer(::VectorLogPotential, ::Inputs) = SliceSampler()

create_reference_log_potential(target::VectorLogPotential, ::Inputs) = 
  VectorLogPotential(target.target_log_potential, target.reference_log_potential, target.reference_sample!, target.dim, true)

sample_iid!(target::VectorLogPotential, replica) = 
  target.reference_sample!(replica.rng, replica.state)