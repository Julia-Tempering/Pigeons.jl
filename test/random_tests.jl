# DELETE THIS FILE LATER

using Distributions
using BenchmarkTools

function main1()
    n = 10000
    x = [[0.0, 0.0, 0.0] for _ in 1:n]
    temp = similar(x[1])

    for i in 2:n
        rand!(Normal(0.0, 1.0), temp)
        x[i] .= x[i-1] .+ temp
    end
end

function main2()
    n = 10000
    x = zeros(n, 3)
    temp = similar(x[1, :])

    for i in 2:n
        rand!(Normal(0.0, 1.0), temp)
        x[i, :] .= @view(x[i-1, :]) .+ temp
    end
end

@btime main2()
