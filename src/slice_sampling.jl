using Distributions
using StatsFuns
using Random
using Plots
using BenchmarkTools
using LinearAlgebra

struct SS
    potential # -log(f(x))
    w # Initial slice size
    p # Slices are no larger than 2^p * w
    dim_fraction # Proportion of variables to update
end
SS(potential) = SS(potential, 1.0, 10, 1.0) # Note the defaults!

function slice_double(h::SS, g, x_0, z, c)
    U = rand(Uniform(0.0, 1.0))
    L = x_0[c] - h.w*U
    R = L + h.w
    K = h.p
    
    Lvec = copy(x_0)
    Lvec[c] = L
    Rvec = copy(x_0)
    Rvec[c] = R

    while (K > 0) && ((z < g(Lvec)) || (z < g(Rvec)))
        V = rand(Uniform(0.0, 1.0))
        if V <= 0.5
            L = L - (R - L)
        else
            R = R + (R - L)
        end
        K = K - 1
        Lvec[c] = L
        Rvec[c] = R
    end
    return(L = L,
           R = R)
end

function slice_shrink(h, g, x_0, z, L, R, c)
    Lbar = L
    Rbar = R

    while true
        U = rand(Uniform(0.0, 1.0))
        x_1 = Lbar + U * (Rbar - Lbar)
        x_1vec = copy(x_0)
        x_1vec[c] = x_1
        if (z < g(x_1vec)) && (slice_accept(h, g, x_0, x_1, z, L, R, c))
            return x_1
        end
        if x_1 < x_0[c]
            Lbar = x_1
        else
            Rbar = x_1
        end
    end
    return x_1
end

function slice_accept(h::SS, g, x_0, x_1, z, L, R, c)
    Lhat = L
    Rhat = R
    Lhatvec = copy(x_0)
    Lhatvec[c] = L
    Rhatvec = copy(x_0)
    Rhatvec[c] = R

    D = false
    acceptable = true

    while Rhat - Lhat > 1.1 * h.w
        M = (Lhat + Rhat)/2.0
        if ((x_0[c] < M) && (x_1 >= M)) || ((x_0[c] >= M) && (x_1 < M))
            D = true
        end
        
        if x_1 < M
            Rhat = M
            Rhatvec[c] = Rhat
        else
            Lhat = M
            Lhatvec[c] = Lhat
        end

        if D && (z >= g(Lhatvec)) && (z >= g(Rhatvec))
            acceptable = false
            return acceptable
        end
    end
    return acceptable
end

function slice_sample(h::SS, x_0::Vector{Float64}, nsamps::Int64)
    g(x) = -h.potential(x) # log(f(x))
    x = Vector{typeof(x_0)}(undef, nsamps + 1)
    x[1] = x_0
    dim_x = length(x_0)

    for i in 2:(nsamps+1)
        C = StatsBase.sample(1:dim_x, Int64(ceil(dim_x*h.dim_fraction)), replace=false) # Set of coordinates to update
        x_0 = deepcopy(x[i-1])
        x_1 = deepcopy(x_0)
        for c in C
            z = g(x_0) - rand(Exponential(1.0)) # log(y)
            L, R = slice_double(h, g, x_0, z, c)
            x_1[c] = slice_shrink(h, g, x_0, z, L, R, c)
            x_0 = deepcopy(x_1)
        end
        x[i] = deepcopy(x_1)
    end
    x = x[2:end] # Remove x_0
    return x
end