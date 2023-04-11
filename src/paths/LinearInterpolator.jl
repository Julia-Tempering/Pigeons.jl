# use this extension point to create new types of interpolations, e.g. q-path, etc.
interpolate(interpolator, ref, target, beta) = @abstract

struct LinearInterpolator end
interpolate(::LinearInterpolator, ref_log_potential, target_log_potential, beta) = 
    (1.0 - beta) * ref_log_potential + beta * target_log_potential