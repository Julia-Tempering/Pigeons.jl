"""
For the stan target, the autodiff for the target is a stan 
call, and is a custom rule for the reference. Each use a 
buffer to avoid heap allocations in the inner loop. 
"""
struct BufferedGradient{T}
    enclosed::T 
    kind::Symbol
    buffer1::Vector{Float64}
    buffer2::Vector{Float64}
end

LogDensityProblems.logdensity(buffered::BufferedGradient, x) = LogDensityProblems.logdensity(buffered.enclosed, x)
LogDensityProblems.dimension(buffered::BufferedGradient) = LogDensityProblems.dimension(buffered.enclosed)

