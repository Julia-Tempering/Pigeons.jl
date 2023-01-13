using Distributions 
using ConcreteStructs
using DynamicPPL
using BenchmarkTools

import Base: @kwdef 

"""
Slice sampler based on
[Neal, 2003](https://projecteuclid.org/journals/annals-of-statistics/volume-31/issue-3/Slice-sampling/10.1214/aos/1056562461.full).
"""
@kwdef @concrete mutable struct SliceSampler
    w = 1.0 # initial slice size
    p = 10 # slices are no larger than 2^p * w
    dim_fraction = 1.0 # proportion of variables to update
end



function slice_sample!(h::SliceSampler, state::AbstractVector, log_potential)
    dim_x = length(state)
    g_x0 = -log_potential(state) # TODO: is it correct to keep the vertical draw out of the loop?
    for c in 1:dim_x # update *every* coordinate (TODO: change this later!)
        z = g_x0 - rand(Exponential(1.0)) # log(vertical draw)
        L, R = slice_double(h, state, z, c, log_potential)
        state[c] = slice_shrink(h, state, z, L, R, c, log_potential)
    end
end

function slice_sample!(h::SliceSampler, state::TypedVarInfo, log_potential)
    dim_x = length(keys(state.metadata))
    state_vector = [0.0 for _ in 1:dim_x] # TODO: remove allocation!
    for c in 1:dim_x
        state_vector[c] = state.metadata[c].vals[1]
    end
    slice_sample!(h, state_vector, log_potential)
    for c in 1:dim_x
        state.metadata[c].vals[1] = state_vector[c]
    end
end


function slice_double(h::SliceSampler, state, z, c::Integer, log_potential)
    old_position = state[c] # store old position (trick to avoid memory allocation)
    U = rand()
    L = state[c] - h.w*U # new left endpoint
    R = L + h.w
    K = h.p
    
    state[c] = L
    neg_potent_L = -log_potential(state) # store the negative log potential
    state[c] = R
    neg_potent_R = -log_potential(state)

    while (K > 0) && ((z < neg_potent_L) || (z < neg_potent_R))
        V = rand()        
        if V <= 0.5
            L = L - (R - L)
            state[c] = L
            neg_potent_L = -log_potential(state) # store the new neg log potential
        else
            R = R + (R - L)
            state[c] = R
            neg_potent_R = -log_potential(state)
        end
        K = K - 1
    end
    state[c] = old_position # return the state back to where it was before
    return(; L, R)
end


function slice_shrink(h::SliceSampler, state, z, L, R, c::Int, log_potential)
    old_position = state[c]
    Lbar = L
    Rbar = R

    while true
        U = rand()
        new_position = Lbar + U * (Rbar - Lbar)
        state[c] = new_position 
        consider = (z < -log_potential(state))
        state[c] = old_position
        if (consider) && (slice_accept(h, state, new_position, z, L, R, c, log_potential))
            return new_position
        end
        if new_position < state[c]
            Lbar = new_position
        else
            Rbar = new_position
        end
    end
    return new_position
end


function slice_accept(h::SliceSampler, state, new_position, z, L, R, c::Int, log_potential)
    old_position = state[c]
    Lhat = L
    Rhat = R

    state[c] = L # trick to avoid memory allocation
    neg_potent_L = -log_potential(state)
    state[c] = R 
    neg_potent_R = -log_potential(state)
    
    D = false
    acceptable = true
    
    while Rhat - Lhat > 1.1 * h.w
        M = (Lhat + Rhat)/2.0
        if ((old_position < M) && (new_position >= M)) || ((old_position >= M) && (new_position < M))
            D = true
        end
        
        if new_position < M
            Rhat = M
            state[c] = Rhat
            neg_potent_R = -log_potential(state)
        else
            Lhat = M
            state[c] = Lhat
            neg_potent_L = -log_potential(state)
        end
        
        if (D && (z >= neg_potent_L) && (z >= neg_potent_R))
            state[c] = old_position 
            return false
        end
    end
    state[c] = old_position
    return acceptable
end



h = SliceSampler()
log_potential = (x) -> -logpdf(Normal(0.0, 1.0), x[1])
include("../src/pt/turing_test.jl")
# println(vi.metadata[1].vals)

function main()
    for i in 1:100
        slice_sample!(h, vi, log_potential)
        # println(vi.metadata[1].vals)
    end
end

@btime main()

