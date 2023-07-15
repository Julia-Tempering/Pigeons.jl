"""
Holds a buffer for in-place auto-differentiation. 
For example, used by stan log potentials. 

Fields: 
$FIELDS
"""
struct BufferedAD{T, L, S}
    """ A struct satisfying the `LogDensityProblems` informal interface. """
    enclosed::T
    
    """ The buffer used for in-place gradient computation. """
    buffer::Vector{Float64}

    """ A buffer for logdensity eval. """
    logd_buffer::L 

    """ A buffer to hold error flags. """
    err_buffer::S
end
LogDensityProblems.logdensity(buffered::BufferedAD, x) = LogDensityProblems.logdensity(buffered.enclosed, x)
LogDensityProblems.dimension(buffered::BufferedAD) = length(buffered.buffer)
BufferedAD(log_potential, buffers::Augmentation, logd_buffer = nothing, err_buffer = nothing) = 
    BufferedAD(
        log_potential,
        get_buffer(buffers, :gradient_buffer, LogDensityProblems.dimension(log_potential)), 
        logd_buffer, 
        err_buffer 
)

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

LogDensityProblemsAD.ADgradient(kind::Symbol, log_potential, buffers::Augmentation) = 
    LogDensityProblemsAD.ADgradient(kind, log_potential)

LogDensityProblemsAD.ADgradient(kind::Symbol, log_potential::InterpolatedLogPotential{InterpolatingPath{R, T, LinearInterpolator}, B}, buffers::Augmentation)  where {R, T, B} = 
    InterpolatedAD(
        log_potential,
        LogDensityProblemsAD.ADgradient(kind, log_potential.path.ref, buffers), 
        LogDensityProblemsAD.ADgradient(kind, log_potential.path.target, buffers), 
        get_buffer(buffers, :gradient_interpolated_buffer, LogDensityProblems.dimension(log_potential.path.ref))
    )

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