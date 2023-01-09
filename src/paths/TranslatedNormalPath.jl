"""
$FIELDS
Toy path for testing.
"""
struct TranslatedNormalPath
    """Path between a MVN with mean zero at one end point and given `mean` at the other."""
    mean::Float64
end
interpolate(path::TranslatedNormalPath, beta) = Normal(beta * path.mean, 1)

