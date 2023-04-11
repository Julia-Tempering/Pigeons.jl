"""
A [`log_potential`](@ref) obtained by evaluation of a [`path`](@ref) at a 
point beta in the closed interval ``[0, 1]``.  
"""
@concrete struct InterpolatedLogPotential
    path
    beta
end

(interpolated::InterpolatedLogPotential)(x) = 
    if interpolated.beta == zero(interpolated.beta)
        interpolated.path.ref(x)
    elseif interpolated.beta == one(interpolated.beta)
        interpolated.path.target(x)
    else
        interpolate(interpolated.path.interpolator, interpolated.path.ref(x), interpolated.path.target(x), interpolated.beta)
    end
