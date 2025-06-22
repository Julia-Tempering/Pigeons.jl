# Paths based on interpolating two log_potential's

@auto struct InterpolatingPath
    ref
    target
    interpolator
end

"""
$SIGNATURES

Given a reference [`log_potential`](@ref) and a target [`log_potential`](@ref), 
return a [`path`](@ref) interpolating between them. 

By default, the `interpolator` is a `LinearInterpolator`, i.e. 
standard annealing.
"""
@provides path InterpolatingPath(ref, target) = InterpolatingPath(ref, target, LinearInterpolator())

interpolate(path::InterpolatingPath, beta) = InterpolatedLogPotential(path, beta)

# use this extension point to create new types of interpolations, e.g. q-path, etc.
interpolate(interpolator, ref, target, beta, x) = @abstract

struct LinearInterpolator end
interpolate(::LinearInterpolator, ref_log_potential, target_log_potential, beta) = 
    (1.0 - beta) * ref_log_potential + beta * target_log_potential


"""
$SIGNATURES

[`InterpolatingPath`](@ref) is already a [`path`](@ref), so return it.
"""
create_path(target::InterpolatingPath, inputs::Inputs) = target_is_already_a_path(target, inputs)

""" 
$SIGNATURES 

Utility to allow the user to specify a path of distribution in inputs.target.
In that case, we verify that inputs.reference was not specified. 
"""
function target_is_already_a_path(target, inputs)
    if !isnothing(inputs.reference)
        error("Conflicting options: inputs.target is already a path, but an explicit inputs.reference was provided.")
    end 
    return target
end

initialization(target::InterpolatingPath, rng::AbstractRNG, replica_index::Int64) = 
    initialization(target.target, rng, replica_index)