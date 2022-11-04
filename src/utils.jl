# α: Percentage of observations to Winsorize at bottom and top (use 1 - 2α observations and Winsorize the rest)
# Note: Assumes that the input is a vector of vectors (!)
function Winsorized_mean(x; α=0.1)
    dim_x = length(x[1])
    out = Vector{Float64}(undef, dim_x)
    n = length(x)
    n_lower = convert(Int64, floor(α*n))

    for j in 1:dim_x
        y = sort(map((i) -> x[i][j], 1:n))
        out[j] = 1/n * (n_lower * y[n_lower] + sum(y[(n_lower + 1):(n - n_lower)]) + n_lower * y[n - n_lower + 1])
    end

    return out
end


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


function lognormalizingconstant(Energies, Schedule)
    n, N = size(Energies)
    Δβ = Schedule[2:end] .- Schedule[1:end-1]
    μ = mean(Energies, dims = 1)[2:end]
    sum(Δβ.*μ)
end


#' Compute η
#'
#' Computes η given ϕ and β
#'
#' @param ϕ Array (K - 1, 2) containing knot parameters
#' @param β Vector of N+1 schedules
#'
function computeEtas(ϕ, β)
    if ϕ != [0.5 0.5]
        error("ϕ must be [0.5 0.5]")
    end

    out = zeros(length(β), 2)
    for i in 1:length(β)
        out[i, 1] = 1.0 - β[i]
        out[i, 2] = β[i]
    end

    return out
end