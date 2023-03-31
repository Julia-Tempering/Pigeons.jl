# use this extension point to create new types of interpolations, e.g. q-path, etc.
interpolate(interpolator, ref, target, beta, x) = @abstract
struct LinearInterpolator end
function interpolate(::LinearInterpolator, ref_log_potential, target_log_potential, beta, x) 
    @assert 0.0 ≤ beta ≤ 1.0
    return  @weighted(1.0 - beta, ref_log_potential(x)) +
            @weighted(beta,       target_log_potential(x))
end

