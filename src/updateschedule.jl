### Update Schedule
# Given the cumulative communication barrier function, find the optimal schedule of size N+1 
function updateschedule(cumulativebarrier, N)
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

function updateschedule(rejection, schedule, N) 
    cumulativebarrier = communicationbarrier(rejection, schedule).cumulativebarrier
    updateschedule(cumulativebarrier, N) 
    return newschedule
end