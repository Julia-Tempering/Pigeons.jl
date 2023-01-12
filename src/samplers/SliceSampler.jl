"""
Slice sampler based on
[Neal, 2003](https://projecteuclid.org/journals/annals-of-statistics/volume-31/issue-3/Slice-sampling/10.1214/aos/1056562461.full).
"""
@kwdef @concrete mutable struct SliceSampler
    w = 1.0 # initial slice size
    p = 10 # slices are no larger than 2^p * w
    dim_fraction = 1.0 # proportion of variables to update
end


"""
$SIGNATURES 
"""
@provides explorer create_explorer(target, inputs) = SliceSampler() # TODO
create_state_initializer(target) = Ref(zeros(target)) # TODO
adapt_explorer(explorer::SliceSampler, _, _) = explorer 
explorer_recorder_builders(::SliceSampler) = [] 
regenerate!(explorer::SliceSampler, replica, shared) = @abstract # TODO or remove

function step!(explorer::SliceSampler, replica, shared)
    log_potential = find_log_potential(replica, shared)
    slice_sample!(explorer, replica.state, log_potential)
end


"""
$SIGNATURES
Slice sample one point.
"""
function slice_sample!(h::SliceSampler, state, log_potential)
    dim_x = length(state)
    g_x0 = -log_potential(state) # TODO: is it mathematically correct to keep the vertical draw of the loop?
    for c in 1:dim_x # update *every* coordinate (change this later!)
        z = g_x0 - rand(Exponential(1.0)) # log(vertical draw)
        L, R = slice_double(h, state, z, c, log_potential)
        state[c] = slice_shrink(h, state, z, L, R, c, log_potential)
    end
end


"""
$SIGNATURES
Double the current slice.
"""
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


"""
$SIGNATURES
Shrink the current slice.
"""
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


"""
$SIGNATURES
Test whether to accept the current slice.
"""
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