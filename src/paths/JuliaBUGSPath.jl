"""
$SIGNATURES

A thin wrapper around a `JuliaBUGS.BUGSModel` to provide a prior-posterior path.
To work with Pigeons, `JuliaBUGS` needs to be imported into the current session.

$FIELDS
"""
@auto struct JuliaBUGSPath
    """
    A `JuliaBUGS.BUGSModel`.
    """
    model

    """
    Model definition (for serialization).
    """
    model_def

    """
    Data (for serialization).
    """
    data
end

# Constructor that automatically extracts model_def and data from model
function JuliaBUGSPath(model)
    JuliaBUGSPath(model, model.model_def, Pigeons.Immutable(model.data))
end
