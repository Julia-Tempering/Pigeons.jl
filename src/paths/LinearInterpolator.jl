struct LinearInterpolator end

interpolate(::LinearInterpolator, ref_log_potential, target_log_potential, beta) = 
    (1.0 - beta) * ref_log_potential + beta * target_log_potential

path_derivative(interpolator, ref_log_potential, target_log_potential, beta) = 
    ref_log_potential - target_log_potential