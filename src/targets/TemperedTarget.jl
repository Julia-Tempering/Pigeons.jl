"""
$SIGNATURES

Tempers the given target's log_potential by a factor `beta`. 
Note that this action is performed on the entire density and so the resulting target need not be normalizable. 
Caution should therefore be taken when this (possibly improper) target is used.

$FIELDS
"""
@auto struct TemperedLogPotential{L}
    """The encapsulated LogPotential."""
    base_log_potential::L

    """
    Inverse temperature (factor by which the base log potential is scaled) with 0 < beta ≤ 1. 
    E.g., beta = 1 corresponds to the exact same functionality as a LogPotential that was 
    not wrapped inside a TemperedLogPotential. 
    """
    beta::Float64
end

base_log_potential(log_potential::TemperedLogPotential) = log_potential.base_log_potential

# evaluate the log density
(ref::TemperedLogPotential)(x) = ref.beta * base_log_potential(ref)(x) 

# initialization
initialization(target::TemperedLogPotential, rng::AbstractRNG, replica_index::Int) =
    initialization(base_log_potential(target), rng, replica_index) 

# default explorer 
default_explorer(target::TemperedLogPotential) = default_explorer(base_log_potential(target)) 

# default reference
default_reference(target::TemperedLogPotential) = default_reference(base_log_potential(target)) 

# iid sampling (doing this would be incorrect....)
function sample_iid!(ref::TemperedLogPotential, replica::Replica{<:AbstractArray}, shared)
    if ref.beta == 1.0
        sample_iid!(base_log_potential(ref), replica, shared)
    else 
        sample_iid!(ref, replica, shared) # defaults to using MCMC, so not really IID
        # this can be overwritten by the user if they know how to sample IID from the tempered target
    end
end

# make it conform to the LogDensityProblems interface (if implemented)
LogDensityProblems.logdensity(log_potential::TemperedLogPotential, x) = log_potential(x)
LogDensityProblems.dimension(log_potential::TemperedLogPotential) = 
    LogDensityProblems.dimension(base_log_potential(log_potential))
