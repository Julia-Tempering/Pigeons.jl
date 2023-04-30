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
    log_potential = find_log_potential(replica, shared)
    cached_lp = get_initial_logp(replica.state, log_potential)
    for i in 1:explorer.n_passes
        cached_lp = slice_sample!(explorer, replica.state, log_potential, cached_lp, replica.rng)
    end
end


"""
$SIGNATURES
Slice sample one point.
"""

function get_initial_logp(state::AbstractVector, log_potential)
    return log_potential(state)
end

function get_initial_logp(state::DynamicPPL.TypedVarInfo, log_potential)
    # for Turing, need to transform to get initial logp for caching
    cached_lp = on_transformed_space(state, log_potential) do
        return log_potential(state)
    end
    return cached_lp
end

function slice_sample!(h::SliceSampler, state::AbstractVector, log_potential, cached_lp, rng)
    for c in 1:length(state) # update every coordinate
        pointer = Ref(state, c)
        cached_lp = slice_sample_coord!(h, state, pointer, log_potential, cached_lp, rng)
    end
    return cached_lp
end

function slice_sample!(h::SliceSampler, state::DynamicPPL.TypedVarInfo, log_potential, cached_lp, rng)
    cached_lp = on_transformed_space(state, log_potential) do
        cl_cached_lp = cached_lp
        for i in 1:length(state.metadata)
            for c in 1:length(state.metadata[i].vals)
                pointer = Ref(state.metadata[i].vals, c)
                cl_cached_lp = slice_sample_coord!(h, state, pointer, log_potential, cl_cached_lp, rng)
            end
        end
        return cl_cached_lp
    end
    return cached_lp
end

function on_transformed_space(sampling_task, state::DynamicPPL.TypedVarInfo, log_potential)
    transform_back = false
    if !DynamicPPL.istrans(state, DynamicPPL._getvns(state, DynamicPPL.SampleFromPrior())[1]) # check if in constrained space
        DynamicPPL.link!!(state, DynamicPPL.SampleFromPrior(), turing_model(log_potential)) # transform to unconstrained space
        transform_back = true # transform it back after log_potential evaluation
    end
    ret = sampling_task()
    if transform_back
        DynamicPPL.invlink!!(state, turing_model(log_potential)) # transform back to constrained space
    end
    return ret
end

function slice_sample_coord!(h, state, pointer, log_potential, cached_lp, rng)
    if pointer[] isa Bool
        cached_lp = Bernoulli_sample_coord!(state, pointer, log_potential, cached_lp, rng) # don't slice sample for {0,1} variables
    else
        z = cached_lp - rand(rng, Exponential(1.0)) # log(vertical draw)
        L, R, lp_L, lp_R = slice_double(h, state, z, pointer, log_potential, rng)
        cached_lp = slice_shrink!(h, state, z, L, R, lp_L, lp_R, pointer, log_potential, rng)
    end
    return cached_lp
end

function Bernoulli_sample_coord!(state, pointer, log_potential, cached_lp, rng)
    if pointer[] == Bool(0)
        lp0 = cached_lp
        pointer[] = Bool(1)
        lp1 = log_potential(state) 
    else
        lp1 = cached_lp
        pointer[] = Bool(0)
        lp0 = log_potential(state)
    end

    if rand(rng) < exp(lp0-lp1)/(1.0 + exp(lp0-lp1))
        pointer[] = Bool(0)
        return lp0
    else
        pointer[] = Bool(1)
        return lp1
    end
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
    return (L, R, potent_L, potent_R)
end

function initialize_slice_endpoints(width, pointer, rng, ::Type{T}) where T <: AbstractFloat
    L = pointer[] - width * rand(rng)
    R = L + width
    return (L, R)
end

function initialize_slice_endpoints(width, pointer, rng, ::Type{T}) where T <: Integer
    width = convert(T, ceil(width))
    L = pointer[] - rand(rng, 0:width)
    R = L + width 
    return (L, R)
end


"""
$SIGNATURES
Shrink the current slice.
"""
function slice_shrink!(h::SliceSampler, state, z, L, R, lp_L, lp_R, pointer, log_potential, rng)
    old_position = pointer[]
    Lbar = L
    Rbar = R

    while true
        new_position = draw_new_position(Lbar, Rbar, rng, typeof(pointer[]))
        pointer[] = new_position 
        new_lp = log_potential(state)
        consider = z < new_lp
        pointer[] = old_position
        if consider && slice_accept(h, state, new_position, z, L, R, lp_L, lp_R, pointer, log_potential)
            pointer[] = new_position
            return new_lp
        end
        if new_position < pointer[]
            Lbar = new_position
        else
            Rbar = new_position
        end
    end
    # code should never get here...
    # TODO do we need these lines for some sort of output type stability or something?
    pointer[] = new_position
    return new_lp
end

draw_new_position(L, R, rng, ::Type{T}) where T <: AbstractFloat = L + rand(rng) * (R-L)
draw_new_position(L, R, rng, ::Type{T}) where T <: Integer = rand(rng, L:R)


"""
$SIGNATURES
Test whether to accept the current slice.
"""
function slice_accept(h::SliceSampler, state, new_position, z, L, R, lp_L, lp_R, pointer, log_potential)
    old_position = pointer[]
    Lhat = L
    Rhat = R
    # tracks whether lp_R,lp_L need to be recomputed
    Rstale = false
    Lstale = false
    
    D = false
    while Rhat - Lhat > 1.1 * h.w
        M = (Lhat + Rhat)/2.0
        if ((old_position < M) && (new_position >= M)) || ((old_position >= M) && (new_position < M))
            D = true
        end
        
        if new_position < M
            Rhat = M
            Rstale = true
        else
            Lhat = M
            Lstale = true
        end

        if D
            if Lstale
                pointer[] = Lhat
                lp_L = log_potential(state)
                Lstale = false
            end
            if Rstale
                pointer[] = Rhat
                lp_R = log_potential(state)
                Rstale = false
            end
            if  ((z >= lp_L) && (z >= lp_R))
                pointer[] = old_position 
                return false
            end
        end
    end
    pointer[] = old_position
    return true
end
