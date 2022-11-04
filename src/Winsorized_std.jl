# α: Percentage of observations to Winsorize at bottom and top (use 1 - 2α observations and Winsorize the rest)
# Note: Assumes that the input is a vector of vectors (!)
function Winsorized_std(x; α=0.1)
    dim_x = length(x[1])
    out = Vector{Float64}(undef, dim_x)
    n = length(x)
    n_lower = convert(Int64, floor(α*n))

    for j in 1:dim_x
        y = map((i) -> x[i][j], 1:n)
        y2 = y .^ 2
        y2 = sort(y2)
        y2_mean = 1/n * (n_lower * y2[n_lower] + sum(y2[(n_lower + 1):(n - n_lower)]) + n_lower * y2[n - n_lower + 1]) # Winsorized estimate of E[Y[j]^2]
        out[j] = sqrt(y2_mean - Winsorized_mean(y; α=α)[1]^2)
    end
    
    return out
end