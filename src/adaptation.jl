"""
    updateschedule(cumulativebarrier, N)

Update the annealing schedule. Given the cumulative communication barrier function
in `cumulativebarrier`, find the optimal schedule of size `N`+1.
"""
function updateschedule(cumulativebarrier, N::Int)
    if N == 1
        newschedule = [0.0, 1.0]
    else 
        Λ = cumulativebarrier(1)
        newschedule = zeros(N+1)
        newschedule[N+1] = 1.0
        for i ∈ 1:N-1
            f(x) = cumulativebarrier(x) - Λ*i/N
            newschedule[i+1] = Roots.find_zero(f, (0.0, 1.0), Roots.Bisection())
        end
    end
    return newschedule
end


"""
    communicationbarrier(rejection, schedule)

Compute the local communication barrier and cumulative barrier functions from the 
`rejection` rates and the current annealing `schedule`. The estimation of the barriers 
is based on Fritsch-Carlson monotonic interpolation.
"""
function communicationbarrier(rejection::Vector{T} where T <: Real, 
                              schedule::Vector{T} where T <: Real)
    x = schedule
    y = [0; cumsum(rejection)]
    spl = Interpolations.interpolate(x, y, FritschCarlsonMonotonicInterpolation())
    cumulativebarrier(β) = spl(β)
    localbarrier(β) = Interpolations.gradient(spl, β)[1]
    globalbarrier = sum(rejection)
    return (localbarrier = localbarrier, cumulativebarrier = cumulativebarrier, globalbarrier = globalbarrier)
end