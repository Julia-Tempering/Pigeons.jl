"""
$SIGNATURES

Uses `DynamicPPL` i.e. `Turing`'s backend to construct the
log density.

To work with Pigeons `DynamicPPL` or `Turing` needs to be imported into
the current session.

$FIELDS
"""
@auto struct TuringLogPotential
    """
    A `DynamicPPL.Model`.
    """
    model

    """
    Either `DynamicPPL.DefaultContext` for evaluating the full joint, or
    `DynamicPPL.PriorContext` for evaluating only the prior.
    """
    context

    """
    The total number of scalar values observed in a single random sample from `model`.
    It is used by the `LogDensityProblems` and `LogDensityProblemsAD` interfaces
    when a gradient-based sampler is used as explorer in models with static 
    computational graphs.
    
    !!! warning
        Explorers targeting models with dynamic computational graphs should not
        depend on the value of this field.
    """
    dimension
end

turing_model(log_potential::TuringLogPotential) = log_potential.model
turing_model(log_potential::InterpolatedLogPotential) = log_potential.path.target.model

# These are functions for the stan examples
# TODO: Should these really be in the main repo or the examples folder?
function toy_turing_target end

"""
$SIGNATURES

A toy Turing model used for testing (unidentifiable 2-dim params for a bernoulli).
"""
function toy_turing_unid_target end
