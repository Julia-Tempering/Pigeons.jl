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
    max_iter::Int = 1_024 # == log2(prevfloat(Inf))
end

explorer_recorder_builders(::SliceSampler) = [explorer_acceptance_pr, explorer_n_steps]

function step!(explorer::SliceSampler, replica, shared)
    log_potential = find_log_potential(replica, shared.tempering, shared)
    cached_lp = -Inf
    for _ in 1:explorer.n_passes
        cached_lp = slice_sample!(explorer, replica.state, log_potential, cached_lp, replica)
    end
end

cached_log_potential(log_potential, state, cached_lp) =
    return if cached_lp == -Inf
        result = log_potential(state)
        if result == -Inf
            error("SliceSampler supports contrained target, but the sampler should be initialized in the support: $state")
        end
        result
    else
        cached_lp
    end

function slice_sample!(h::SliceSampler, state::AbstractVector, log_potential, cached_lp, replica)
    cached_lp = cached_log_potential(log_potential, replica.state, cached_lp) # note: we pass `replica.state` instead of `state` in case the latter is the vector version of a non-vector state (e.g. stan and dppl models)
    
    # iterate over coordinates
    for c in eachindex(state)
        pointer = Ref(state, c)
        cached_lp = slice_sample_coord!(h, replica, pointer, log_potential, cached_lp, typeof(pointer[])) # note: when state is mixed, pointer is RefArray{generic common type} for all coordinates, so can't use it to dispatch 

        # check we still have a healthy state
        if !isfinite(cached_lp)
            error("""Got an invalid log density after updating state at index $c:
            - log density = $cached_lp
            - state[$c]   = $(pointer[])
            Dumping full replica state:
            $(replica.state)
            """)
        end
    end
    return cached_lp
end

# handle Bools separately: sample from the full conditional (requires 1 density eval)
function slice_sample_coord!(h, replica, pointer, log_potential, cached_lp, ::Type{Bool})
    state = replica.state
    rng = replica.rng
    if pointer[]                    # currently true => already have lp1
        lp1 = cached_lp
        pointer[] = false
        lp0 = log_potential(state)
    else                            # currently false => already have lp0
        lp0 = cached_lp
        pointer[] = true
        lp1 = log_potential(state)
    end
    prob_ratio = exp(lp1-lp0)
    prob_zero = inv(1 + prob_ratio) # r = p1/p0 => p1 = p0r and p0 + p1=1 => p0(1+r) = 1 => p0=1/(1+r)
    if rand(rng) < prob_zero
        pointer[] = false
        return lp0
    else
        pointer[] = true
        return lp1
    end
end

# generic case: use slicing
function slice_sample_coord!(h, replica, pointer, log_potential, cached_lp, ::Type)
    rng = replica.rng
    z = cached_lp - randexp(rng) # log(vertical draw)
    L, R, lp_L, lp_R = slice_double(h, replica, z, pointer, log_potential)
    cached_lp = slice_shrink!(h, replica, z, L, R, lp_L, lp_R, pointer, log_potential)
    return cached_lp
end

function slice_double(h::SliceSampler, replica, z, pointer, log_potential)
    rng = replica.rng
    state = replica.state
    old_position = pointer[] # store old position while avoiding memory allocation
    L, R = initialize_slice_endpoints(pointer[], h.w, rng)
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
        K -= 1
    end
    @record_if_requested!(replica.recorders, :explorer_n_steps, (replica.chain, h.p - K))

    pointer[] = old_position # return the state back to where it was before
    return (L, R, potent_L, potent_R)
end

# generic case
function initialize_slice_endpoints(current, width, rng)
    L = current - width * rand(rng)
    R = L + width
    return (L, R)
end

# handle integers separately
function initialize_slice_endpoints(current::T, width, rng) where {T<:Integer}
    width = ceil(T, width)
    L = current - rand(rng, 0:width)
    R = L + width
    return (L, R)
end

function slice_shrink!(h::SliceSampler, replica, z, L, R, lp_L, lp_R, pointer, log_potential)
    rng = replica.rng
    state = replica.state
    old_position = pointer[]
    Lbar = L
    Rbar = R
    new_lp = zero(z) # init the variable new_lp so it lives outside the `while` scope
    n = 1

    while n <= h.max_iter
        new_position = draw_new_position(Lbar, Rbar, rng)
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

draw_new_position(L, R, rng) = L + rand(rng) * (R-L)
draw_new_position(L::Integer, R::Integer, rng) = rand(rng, L:R)


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
