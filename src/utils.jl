"""
    Winsorized_mean(x; α)

Compute the Winsorized mean from an input `x`, which is assumed to be a vector of vectors. 
`α` denotes the percentage of observations to Winsorize at the bottom and the top 
so that we use 1 - 2α observations and Winsorize the rest.
"""
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


"""
    Winsorized_std(x; α)

Compute the Winsorized standard deviation. The parameters are the same 
as those for `Winsorized_mean()`.
"""
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


"""
    lognormalizingconstant(Energies, Schedule)

Compute an estimate of the log normalizing constant given a vector of 
`Energies` and the corresponding annealing `Schedule`.
"""
function lognormalizingconstant(Energies, Schedule)
    n, N = size(Energies)
    Δβ = Schedule[2:end] .- Schedule[1:end-1]
    μ = mean(Energies, dims = 1)[2:end]
    sum(Δβ.*μ)
end


"""
    computeEtas(ϕ, β)

Compute the `Etas` matrix given `ϕ`, which is an Array(K - 1, 2) containing 
knot parameters, and `β`, a vector of `N`+1 schedules. For linear paths, 
the function returns an (N+1)x2 matrix with entries 1-β in the first column 
and β in the second column. (This function is useful for those wishing to consider
non-linear paths. However, full support is provided only for linear paths at 
the moment.) 
"""
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