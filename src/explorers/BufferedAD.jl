"""
Holds a buffer for in-place auto-differentiation. 
For example, used by stan log potentials. 

Fields: 
$FIELDS
"""
struct BufferedAD{T, B, L, S}
    """ A struct satisfying the `LogDensityProblems` informal interface. """
    enclosed::T
    
    """ The buffer used for in-place gradient computation. """
    buffer::B

    """ A buffer for logdensity eval. """
    logd_buffer::L 

    """ A buffer to hold error flags. """
    err_buffer::S
end
LogDensityProblems.logdensity(buffered::BufferedAD, x) = LogDensityProblems.logdensity(buffered.enclosed, x)
LogDensityProblems.dimension(buffered::BufferedAD) = LogDensityProblems.dimension(buffered.enclosed)
BufferedAD(log_potential, buffers::Augmentation, logd_buffer = nothing, err_buffer = nothing) = 
    BufferedAD(
        log_potential,
        get_buffer(buffers, :gradient_buffer, LogDensityProblems.dimension(log_potential)), 
        logd_buffer, 
        err_buffer 
)

# translate Symbols+Vals to ADType
LogDensityProblemsAD.ADgradient(kind, log_potential, replica::Replica; kwargs...) = 
    ADgradient(ADTypes.Auto(kind), log_potential, replica; kwargs...)

# default implementation of the ADgradient interface
LogDensityProblemsAD.ADgradient(kind::ADTypes.AbstractADType, log_potential, replica::Replica; kwargs...) =
    ADgradient(kind, log_potential, replica.recorders.buffers; kwargs...)
LogDensityProblemsAD.ADgradient(kind::ADTypes.AbstractADType, log_potential, buffers::Augmentation; kwargs...) =
    Pigeons.BufferedAD(ADgradient(kind, log_potential; kwargs...), buffers)

# default case does not use the buffer
LogDensityProblems.logdensity_and_gradient(buffered::BufferedAD, x) = 
    LogDensityProblems.logdensity_and_gradient(buffered.enclosed, x)

"""
The target and reference may used different autodiff frameworks; 
provided both are non-allocating, this allows autodiff of 
`InterpolatedLogPotential`'s to also be non-allocating. 
For example, this is useful when the target is a stan log potential 
and the reference is a variational distribution with a hand-crafted, 
also allocation-free differentiation.

Fields:
$FIELDS
"""
@auto struct InterpolatedAD
    """ The enclosed `InterpolatedLogPotential`. """
    enclosed

    """ 
    The result of `LogDensityProblemsAD.ADgradient()` on the reference, often a 
    `BufferedAD`. 
    """
    ref_ad

    """ 
    The same as `ref_ad` but with the target.  
    """
    target_ad

    """ An extra buffer to combine the two distribution endpoints gradients. """
    buffer::Vector{Float64}
end

function LogDensityProblemsAD.ADgradient(
    kind::ADTypes.AbstractADType,
    log_potential::InterpolatedLogPotential{<:InterpolatingPath{<:Any,<:Any,LinearInterpolator}},
    replica::Replica
    )
    ad_buffers = replica.recorders.ad_buffers
    ref_ad = get_buffer(ad_buffers, :reference, kind, log_potential.path.ref, replica)
    target_ad = get_buffer(ad_buffers, :target, kind, log_potential.path.target, replica)
    InterpolatedAD(
        log_potential, ref_ad, target_ad,
        get_buffer(replica.recorders.buffers, :gradient_interpolated_buffer, LogDensityProblems.dimension(ref_ad))
    )
end

function LogDensityProblems.logdensity(log_potential::InterpolatedAD, x) 
    l1 = LogDensityProblems.logdensity(log_potential.ref_ad, x)
    l2 = LogDensityProblems.logdensity(log_potential.target_ad, x) 
    beta = log_potential.enclosed.beta
    return (1.0 - beta) * l1 + beta * l2
end

LogDensityProblems.dimension(log_potential::InterpolatedAD) = LogDensityProblems.dimension(log_potential.ref_ad)

function LogDensityProblems.logdensity_and_gradient(log_potential::InterpolatedAD, x)
    logdens = 0.0
    beta = log_potential.enclosed.beta
    buffer = log_potential.buffer

    l, g = LogDensityProblems.logdensity_and_gradient(log_potential.ref_ad, x)
    logdens += l * (1.0 - beta)
    buffer .= g .* (1.0 - beta)

    l, g = LogDensityProblems.logdensity_and_gradient(log_potential.target_ad, x)
    logdens += l * beta
    buffer .= buffer .+ g .* beta

    return logdens, buffer
end

"""
$SIGNATURES 

An [`Augmentation`](@ref) for [`Pigeons.BufferedAD`](@ref).
"""
ad_buffers() = buffers(Pigeons.BufferedAD)

"""
$SIGNATURES 

Return a [`Pigeons.BufferedAD`](@ref) if it exists in the [`Augmentation`](@ref).
Otherwise it constructs one and then stores it to avoid reconstructing it in the
future.

!!! note
    This implementation is not type stable (the value type of the `Dict` is not 
    concrete). However, the runtime dispatch cost incurred should be more than 
    compensated by the ability to avoid reconstructing AD objects at each 
    exploration step.
"""
function get_buffer(a::Augmentation{<:Dict{Symbol, BufferedAD}}, key::Symbol, args...)
    dict = a.contents
    if !haskey(dict, key)
        dict[key] = LogDensityProblemsAD.ADgradient(args...)
    end
    return dict[key]
end

# used in the AD extensions
abstract type ADWrapper end
LogDensityProblems.logdensity(adw::ADWrapper, x::AbstractVector) = 
    LogDensityProblems.logdensity(adw.log_potential, x)
LogDensityProblems.dimension(adw::ADWrapper) = 
    LogDensityProblems.dimension(adw.log_potential)
