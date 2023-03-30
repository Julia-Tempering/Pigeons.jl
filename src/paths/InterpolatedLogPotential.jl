"""
A [`log_potential`](@ref) obtained by evaluation of a [`path`](@ref) at a 
point beta in the closed interval ``[0, 1]``.  
"""
@concrete struct InterpolatedLogPotential
    path
    beta
end

interpolate(interpolator, ref_log_potential, target_log_potential, beta, x) = 
    interpolate(interpolator, ref_log_potential(x), target_log_potential(x), beta)

function interpolate(::LinearInterpolator, ref_log_potential_value, target_log_potential_value, beta) 
    @assert 0.0 ≤ beta ≤ 1.0
    @weighted(1.0 - beta, ref_log_potential_value) +
    @weighted(beta,       target_log_potential_value)
end
