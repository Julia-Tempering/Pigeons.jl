"""
Slice sampler based on
[Neal, 2003](https://projecteuclid.org/journals/annals-of-statistics/volume-31/issue-3/Slice-sampling/10.1214/aos/1056562461.full).

Fields:
$FIELDS
"""
@kwdef struct SliceSampler
    """ Initial slice size. """
    w::Float64 = 10.0 

    """ Slices are no larger than 2^p * w """
    p::Int = 20 

    """ Number of passes through all variables per exploration step. """
    n_passes::Int = 3  

    """ Maximum number of interations inside shrink_slice! before erroring out """
    max_iter::Int = 4_096  
end

explorer_recorder_builders(::SliceSampler) = [explorer_acceptance_pr, explorer_n_steps]

function step!(explorer::SliceSampler, replica, shared)
    log_potential = find_log_potential(replica, shared.tempering, shared)
    cached_lp = -Inf
    for i in 1:explorer.n_passes
        cached_lp = slice_sample!(explorer, replica.state, log_potential, cached_lp, replica)
    end
end

function cached_log_potential(log_potential, state, cached_lp)
    return if cached_lp == -Inf 
        result = log_potential(state)
        if result == -Inf 
            error("SliceSampler supports contrained target, but the sampler should be initialized in the support: $state")
        end
        return result
    else
        cached_lp
    end
end

function slice_sample!(h::SliceSampler, state::AbstractVector, log_potential, cached_lp, replica)
    cached_lp = cached_log_potential(log_potential, state, cached_lp)
    # iterate over coordinates
    for c in 1:length(state) 
        pointer = Ref(state, c)
        cached_lp = slice_sample_coord!(h, replica, pointer, log_potential, cached_lp)
    end
    return cached_lp
end

function slice_sample!(h::SliceSampler, state::DynamicPPL.TypedVarInfo, log_potential, cached_lp, replica)
    cached_lp = cached_log_potential(log_potential, state, cached_lp)
    for i in 1:length(state.metadata)
        for c in 1:length(state.metadata[i].vals)
            pointer = Ref(state.metadata[i].vals, c)
            cached_lp = slice_sample_coord!(h, replica, pointer, log_potential, cached_lp)
        end
    end
    return cached_lp
end

function slice_sample!(h::SliceSampler, state::StanState, log_potential, cached_lp, replica)
    cached_lp = cached_log_potential(log_potential, state, cached_lp)
    for i in eachindex(state.unconstrained_parameters)
        pointer = Ref(state.unconstrained_parameters, i)
        cached_lp = slice_sample_coord!(h, replica, pointer, log_potential, cached_lp)
    end
    return cached_lp
end

function slice_sample_coord!(h, replica, pointer, log_potential, cached_lp)
    rng = replica.rng
    if pointer[] isa Bool
        cached_lp = Bernoulli_sample_coord!(replica, pointer, log_potential, cached_lp) # don't slice sample for {0,1} variables
    else
        z = cached_lp - rand(rng, Exponential(1.0)) # log(vertical draw)
        L, R, lp_L, lp_R = slice_double(h, replica, z, pointer, log_potential)
        cached_lp = slice_shrink!(h, replica, z, L, R, lp_L, lp_R, pointer, log_potential)
    end
    return cached_lp
end

function Bernoulli_sample_coord!(replica, pointer, log_potential, cached_lp)
    state = replica.state 
    rng = replica.rng
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

function slice_double(h::SliceSampler, replica, z, pointer, log_potential)
    rng = replica.rng
    state = replica.state
    old_position = pointer[] # store old position while avoiding memory allocation
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
    @record_if_requested!(replica.recorders, :explorer_n_steps, (replica.chain, h.p - K)) 

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

function slice_shrink!(h::SliceSampler, replica, z, L, R, lp_L, lp_R, pointer, log_potential)
    @assert isfinite(z)
    rng = replica.rng
    state = replica.state
    old_position = pointer[]
    Lbar = L
    Rbar = R
    new_lp = zero(z) # init the variable new_lp so it lives outside the `while` scope
    n = 1

    while n <= h.max_iter
        new_position = draw_new_position(Lbar, Rbar, rng, typeof(pointer[]))
        pointer[] = new_position 
        new_lp = log_potential(state)
        consider = z < new_lp 
        pointer[] = old_position
        if consider && slice_accept(h, replica, new_position, z, L, R, lp_L, lp_R, pointer, log_potential)
            pointer[] = new_position
            @record_if_requested!(replica.recorders, :explorer_n_steps, (replica.chain, n)) 
            return new_lp
        end
        if new_position < pointer[]
            Lbar = new_position
        else
            Rbar = new_position
        end
        n += 1
    end
    # code should never get here, because eventually
    # shrinkage should produce an acceptable point
    error("""Maximum number of iterations $(h.max_iter) reached. Dumping info:
            - Lbar   = $Lbar
            - Rbar   = $Rbar
            - new_lp = $new_lp
            - z      = $z
    """)
    return 0.0
end

draw_new_position(L, R, rng, ::Type{T}) where T <: AbstractFloat = L + rand(rng) * (R-L)
draw_new_position(L, R, rng, ::Type{T}) where T <: Integer = rand(rng, L:R)


function slice_accept(h::SliceSampler, replica, new_position, z, L, R, lp_L, lp_R, pointer, log_potential)
    state = replica.state
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
                @record_if_requested!(replica.recorders, :explorer_acceptance_pr, (replica.chain, 0.0))
                return false
            end
        end
    end
    pointer[] = old_position
    @record_if_requested!(replica.recorders, :explorer_acceptance_pr, (replica.chain, 1.0))
    return true
end
