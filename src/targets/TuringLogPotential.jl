"""
Uses `DynamicPPL` i.e. `Turing`'s backend to construct the
log density.

To work with Pigeons `DynamicPPL` or `Turing` needs to be imported into
the current session.
"""
@auto struct TuringLogPotential
    model
    only_prior::Bool
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
