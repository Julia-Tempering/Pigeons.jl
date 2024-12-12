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
    Set of names of unobserved parameters in the model.
    """
    parameter_names
end
