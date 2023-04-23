"""
Slice sampler based on
[Neal, 2003](https://projecteuclid.org/journals/annals-of-statistics/volume-31/issue-3/Slice-sampling/10.1214/aos/1056562461.full).
"""
@kwdef @concrete struct SliceSampler
    w = 10.0 # initial slice size
    p = 20 # slices are no larger than 2^p * w
    n_passes = 3 # n_passes through all variables per exploration step
end

adapt_explorer(explorer::SliceSampler, _, _) = explorer 
explorer_recorder_builders(::SliceSampler) = [] 

function step!(explorer::SliceSampler, replica, shared)
    for i in 1:explorer.n_passes
        log_potential = find_log_potential(replica, shared)
        slice_sample!(explorer, replica.state, log_potential, replica.rng)
    end
end


"""
$SIGNATURES
Slice sample one point.
"""
function slice_sample!(h::SliceSampler, state::AbstractVector, log_potential, rng)
    for c in 1:length(state) # update *every* coordinate
        g_x0 = log_potential(state)
        pointer = Ref(state, c)
        slice_sample_coord!(h, state, pointer, log_potential, g_x0, rng)
    end
end

function slice_sample!(h::SliceSampler, state::DynamicPPL.TypedVarInfo, log_potential, rng)
    on_transformed_space(state, log_potential) do
        for i in 1:length(state.metadata)
            for c in 1:length(state.metadata[i].vals)
                g_x0 = log_potential(state)
                pointer = Ref(state.metadata[i].vals, c)
                slice_sample_coord!(h, state, pointer, log_potential, g_x0, rng)
            end
        end
    end
end

function on_transformed_space(sampling_task, state::DynamicPPL.TypedVarInfo, log_potential)
    transform_back = false
    if !DynamicPPL.istrans(state, DynamicPPL._getvns(state, DynamicPPL.SampleFromPrior())[1]) # check if in constrained space
        DynamicPPL.link!!(state, DynamicPPL.SampleFromPrior(), turing_model(log_potential)) # transform to unconstrained space
        transform_back = true # transform it back after log_potential evaluation
    end
    sampling_task()
    if transform_back
        DynamicPPL.invlink!!(state, turing_model(log_potential)) # transform back to constrained space
    end
end

function slice_sample_coord!(h, state, pointer, log_potential, g_x0, rng)
    if pointer[] isa Bool
        Bernoulli_sample_coord!(state, pointer, log_potential, rng) # don't slice sample for {0,1} variables
    else
        z = g_x0 - rand(rng, Exponential(1.0)) # log(vertical draw)
        L, R = slice_double(h, state, z, pointer, log_potential, rng)
        pointer[] = slice_shrink(h, state, z, L, R, pointer, log_potential, rng)
    end
end

function Bernoulli_sample_coord!(state, pointer, log_potential, rng)
    pointer[] = Bool(0)
    log_potent_0 = log_potential(state)
    pointer[] = Bool(1)
    log_potent_1 = log_potential(state)
    log_ratio = log_potent_0 - log_potent_1
    if rand(rng) < log_ratio/(1+log_ratio)
        pointer[] = Bool(0)
    end # otherwise already set to 1
end

"""
$SIGNATURES
Double the current slice.
"""
function slice_double(h::SliceSampler, state, z, pointer, log_potential, rng)
    old_position = pointer[] # store old position (trick to avoid memory allocation)
    L, R = initialize_slice_endpoints(h.w, pointer, rng, typeof(pointer[])) # dispatch on either float or int
    K = h.p
    
    pointer[] = L
    potent_L = log_potential(state) # store the log potential
    pointer[] = R
    potent_R = log_potential(state)

    while (K > 0) && ((z < potent_L) || (z < potent_R))
        V = rand(rng)        
        if V <= 0.5
            L = L - (R - L)
            pointer[] = L
            potent_L = log_potential(state) # store the new log potential
        else
            R = R + (R - L)
            pointer[] = R
            potent_R = log_potential(state)
        end
        K = K - 1
    end
    pointer[] = old_position # return the state back to where it was before
    return(; L, R)
end

function initialize_slice_endpoints(width, pointer, rng, ::Type{T}) where T <: AbstractFloat
    L = pointer[] - width * rand(rng)
    R = L + width
    return(; L, R)
end

function initialize_slice_endpoints(width, pointer, rng, ::Type{T}) where T <: Integer
    width = convert(T, ceil(width))
    L = pointer[] - rand(rng, 0:width)
    R = L + width 
    return(; L, R)
end


"""
$SIGNATURES
Shrink the current slice.
"""
function slice_shrink(h::SliceSampler, state, z, L, R, pointer, log_potential, rng)
    old_position = pointer[]
    Lbar = L
    Rbar = R

    while true
        new_position = draw_new_position(Lbar, Rbar, rng, typeof(pointer[]))
        pointer[] = new_position 
        consider = z < log_potential(state)
        pointer[] = old_position
        if consider && slice_accept(h, state, new_position, z, L, R, pointer, log_potential)
            return new_position
        end
        if new_position < pointer[]
            Lbar = new_position
        else
            Rbar = new_position
        end
    end
    return new_position
end

draw_new_position(L, R, rng, ::Type{T}) where T <: AbstractFloat = L + rand(rng) * (R-L)
draw_new_position(L, R, rng, ::Type{T}) where T <: Integer = rand(rng, L:R)


"""
$SIGNATURES
Test whether to accept the current slice.
"""
function slice_accept(h::SliceSampler, state, new_position, z, L, R, pointer, log_potential)
    old_position = pointer[]
    Lhat = L
    Rhat = R

    pointer[] = L # trick to avoid memory allocation
    neg_potent_L = log_potential(state)
    pointer[] = R 
    neg_potent_R = log_potential(state)
    
    D = false
    acceptable = true
    
    while Rhat - Lhat > 1.1 * h.w
        M = (Lhat + Rhat)/2.0
        if ((old_position < M) && (new_position >= M)) || ((old_position >= M) && (new_position < M))
            D = true
        end
        
        if new_position < M
            Rhat = M
            pointer[] = Rhat
            neg_potent_R = log_potential(state)
        else
            Lhat = M
            pointer[] = Lhat
            neg_potent_L = log_potential(state)
        end
        
        if (D && (z >= neg_potent_L) && (z >= neg_potent_R))
            pointer[] = old_position 
            return false
        end
    end
    pointer[] = old_position
    return acceptable
end