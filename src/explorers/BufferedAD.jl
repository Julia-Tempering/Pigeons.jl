struct BufferedAD{T}
    enclosed::T
    buffer::Vector{Float64}
end
LogDensityProblems.logdensity(buffered::BufferedAD, x) = LogDensityProblems.logdensity(buffered.enclosed, x)
LogDensityProblems.dimension(buffered::BufferedAD) = LogDensityProblems.dimension(buffered.enclosed)

@auto struct InterpolatedAD
    enclosed
    ref_ad
    target_ad
    buffer::Vector{Float64}
end

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

    l, g = LogDensityProblems.logdensity_and_gradient(log_potential.ref_ad, x)
    logdens += l * (1.0 - beta)
    log_potential.buffer .= g * (1.0 - beta)

    l, g = LogDensityProblems.logdensity_and_gradient(log_potential.target_ad, x)
    logdens += l * beta
    log_potential.buffer .= log_potential.buffer .+ g * beta

    return logdens, log_potential.buffer
end