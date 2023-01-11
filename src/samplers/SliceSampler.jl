"""
Slice sampler based on [Neal, 2003](https://projecteuclid.org/journals/annals-of-statistics/volume-31/issue-3/Slice-sampling/10.1214/aos/1056562461.full)
Implements the methods [`step!()`](@ref), ... TODO
"""
@kwdef mutable struct SliceSampler{U, W, P, D, C, X}
    potential::U # -log(f(x))
    w::W = 1.0 # initial slice size
    p::P = 10 # slices are no larger than 2^p * w
    dim_fraction::D = 1.0 # proportion of variables to update

    # Private
    C::C = [0]
    x_1::X = [0.0]
    Lvec::X = [0.0]
    Rvec::X = [0.0]
    x_1vec::X = [0.0]
end


"""
$SIGNATURES 
"""
@provides explorer create_explorer(target, inputs) = ToyExplorer()
create_state_initializer(target::ScaledPrecisionNormalPath) = Ref(zeros(target.dim))
step!(explorer::ToyExplorer, replica, shared) = regenerate!(explorer, replica, shared)
adapt_explorer(explorer::ToyExplorer, _, _) = explorer 
explorer_recorder_builders(::ToyExplorer) = [] 
function regenerate!(explorer::ToyExplorer, replica, shared)
    log_potential = find_log_potential(replica, shared) 
    replica.state = rand(replica.rng, log_potential)
end




"""
$SIGNATURES
Double the current slice.
"""
function slice_double(h::SliceSampler, x_0::Vector{T}, z, c::Integer) where {T}
    U = rand()
    L = x_0[c] - h.w*U
    R = L + h.w
    K = h.p
    
    h.Lvec .= x_0
    h.Lvec[c] = L
    h.Rvec .= x_0
    h.Rvec[c] = R

    while (K > 0) && ((z < -h.potential(h.Lvec)) || (z < -h.potential(h.Rvec)))
        V = rand()
        if V <= 0.5
            L = L - (R - L)
        else
            R = R + (R - L)
        end
        K = K - 1
        h.Lvec[c] = L
        h.Rvec[c] = R
    end
    return(; L, R)
end


"""
$SIGNATURES
Shrink the current slice.
"""
function slice_shrink(h::SliceSampler, x_0::Vector{T}, z, L::T, R::T, c::Integer) where {T}
    Lbar = L
    Rbar = R

    while true
        U = rand()
        x_1 = Lbar + U * (Rbar - Lbar)
        h.x_1vec .= x_0
        h.x_1vec[c] = x_1
        if (z < -h.potential(h.x_1vec)) && (slice_accept(h, x_0, x_1, z, L, R, c))
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


"""
$SIGNATURES
Test whether to accept the current slice.
"""
function slice_accept(h::SliceSampler, x_0::Vector{T}, x_1, z, L::T, 
                      R::T, c::Integer) where {T}
    Lhat = L
    Rhat = R
    h.Lvec .= x_0
    h.Lvec[c] = L
    h.Rvec .= x_0
    h.Rvec[c] = R

    D = false
    acceptable = true

    while Rhat - Lhat > 1.1 * h.w
        M = (Lhat + Rhat)/2.0
        if ((x_0[c] < M) && (x_1 >= M)) || ((x_0[c] >= M) && (x_1 < M))
            D = true
        end
        
        if x_1 < M
            Rhat = M
            h.Rvec[c] = Rhat
        else
            Lhat = M
            h.Lvec[c] = Lhat
        end

        if D && (z >= -h.potential(h.Lvec)) && (z >= -h.potential(h.Rvec))
            acceptable = false
            return acceptable
        end
    end
    return acceptable
end


"""
$SIGNATURES
Slice sample `n` points given a starting vector  `x_0` and the struct `h` 
that contains information about the log-density.
"""
function slice_sample(h::SliceSampler, x_0::Vector{T}, n::Integer) where {T}
    dim_x = length(x_0)
    x = [[0.0 for j in 1:dim_x] for i in 1:(n+1)]
    x[1] = x_0
    h.C .= zeros(Integer, Int64(ceil(dim_x * h.dim_fraction)))
    h.x_1 .= similar(x_0)

    for i in 2:(n+1)
        StatsBase.sample!(1:dim_x, h.C; replace = false) # coordinates to update
        h.x_1 = x[i-1]
        g_x_0 = -h.potential(h.x_1)
        for c in h.C
            z = g_x_0 - rand(Exponential(1.0)) # log(y)
            L, R = slice_double(h, h.x_1, z, c)
            h.x_1[c] = slice_shrink(h, h.x_1, z, L, R, c)
        end
        x[i] .= h.x_1
    end
    deleteat!(x, 1) # remove x_0
    return x
end