"""
A [`log_potential`](@ref) obtained by evaluation of a [`path`](@ref) at a point beta. 
"""
@concrete struct InterpolatedLogPotential
    path
    beta
end

(interpolated::InterpolatedLogPotential)(x) = 
    interpolate(interpolated.path.interpolator, interpolated.path.ref, interpolated.path.target, interpolated.beta, x)
