"""
$SIGNATURES

A thin wrapper around a `JuliaBUGS.BUGSModel`. 
To work with Pigeons, `JuliaBUGS` needs to be imported into the current session.

$FIELDS
"""
@auto struct JuliaBUGSLogPotential
    """
    A `JuliaBUGS.BUGSModel`.
    """
    model
end
