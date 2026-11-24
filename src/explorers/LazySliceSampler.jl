"""
    LazySliceSampler(; w = 1.0, n_passes = 3)

Coordinate-wise lazy doubling slice sampler. Between PT rounds, widths are
tuned separately for each chain and continuous coordinate as a function of
the log slice height, using the one-shot quantile rule from
[Campbell, 2026](https://arxiv.org/abs/2609.08172). `w` is the initial
width (and the fixed width for integer coordinates); `n_passes` is the
number of coordinate sweeps per kernel iteration. 
Adaptation is based on iterations from the preceding round.
"""
@kwdef struct LazySliceSampler
    w::Float64 = 1.0
    n_passes::Int = 3
    widths::Dict{Tuple{Int,Int}, Tuple{Vector{Float64},Vector{Float64}}} =
        Dict{Tuple{Int,Int}, Tuple{Vector{Float64},Vector{Float64}}}()
end

function get_w(h::LazySliceSampler, key, y)
	# get the tuned width function for this coordinate
    bins = get(h.widths, key, nothing)
    bins === nothing && return h.w
    # search for the current slice value y, and return the corresponding width
    heights, widths = bins
    return widths[min(searchsortedfirst(heights, y), length(widths))]
end

function step!(h::LazySliceSampler, replica, shared)
	# check validity of the LazySlicer struct
	(isfinite(h.w) && h.w > 0) || error("LazySliceSampler requires a finite positive initial width guess w")
	h.n_passes > 0 || error("LazySliceSampler requires a positive integer number of passes n_passes")
	# get the log potential function
    log_potential = find_log_potential(replica, shared.tempering, shared)
    # do n_passes of slice sampling. Initialize cached_lp to -Inf to indicate that it needs to be computed in each iteration 
    cached_lp = -Inf
    for _ in 1:h.n_passes
        cached_lp = slice_sample!(h, replica.state, log_potential, cached_lp, replica)
    end
end

function slice_sample!(h::LazySliceSampler, state::AbstractVector, log_potential, cached_lp, replica, offset=0)
	# if the logprob is cached, use it; otherwise recompute it
	if cached_lp == -Inf
    	@record_if_requested!(replica.recorders, :explorer_n_steps, (replica.chain, 1))
        cached_lp = log_potential(replica.state)
    end
	isfinite(cached_lp) || error("LazySliceSampler requires a finite initial log density, got $cached_lp")

    for (i, c) in enumerate(eachindex(state))
        pointer = Ref(state, c)
		cached_lp = slice_coord!(h, replica, pointer, log_potential, cached_lp, (replica.chain, offset + i), typeof(pointer[]))
        isfinite(cached_lp) || error("LazySliceSampler coordinate move returned a state with an invalid log density $cached_lp at coordinate $c")
    end
    return cached_lp
end

# handle Bools separately: sample from the full conditional (requires 1 density eval)
function slice_coord!(h::LazySliceSampler, replica, pointer, log_potential, cached_lp, coordinate_index, ::Type{Bool})
    state = replica.state
    rng = replica.rng
    @record_if_requested!(replica.recorders, :explorer_n_steps, (replica.chain, 1))
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

struct SliceBoundsTrackingEvaluator{P,F,S}
    pointer::P
    log_potential::F
    state::S
    z::Float64
	inside::Vector{Float64}
    outside::Vector{Float64}
end

function tracked_slice_eval!(t::SliceBoundsTrackingEvaluator, x)
	# update the relevant coordinate in the state and compute logp
    t.pointer[] = x
    lp = t.log_potential(t.state)
	if isnan(lp)
		@warn "LazySliceSampler: log_potential output $lp at $x. Treating as -Inf."
		lp = -Inf
	end
	# if the computed logp is in the slice, update the inner bounds; otherwise keep track of it for the outer bounds
    if lp >= t.z
		t.inside[1] = min(t.inside[1], x)
		t.inside[2] = max(t.inside[2], x)
    else
        push!(t.outside, x)
    end
    return lp
end

function slice_coord!(h::LazySliceSampler, replica, pointer, log_potential, cached_lp, key, ::Type{<:Real})
    x = pointer[]
    # draw the slice variable
    z = cached_lp - randexp(replica.rng)
    # get the appropriate initial slice-adaptive tuned window width
    w = get_w(h, key, z)
	t = SliceBoundsTrackingEvaluator(pointer, log_potential, replica.state, z, [float(x), float(x)], Float64[])
	# find the approximate slice interval with lazy caching
    L, R, lp_L, lp_R, cache = slice_double!(t, replica, x, w)
    # shrinkage procedure with lazy caching
    new_x, new_lp = slice_shrink!(t, replica, x, cached_lp, L, R, lp_L, lp_R, cache)
    # the slicer iteration is now done; just tracking for tuning left
	# compute the outer slice bounds
	inner_left = t.inside[1]
	inner_right = t.inside[2]
    outer_left = -Inf 
    outer_right = Inf
    for y in t.outside
		y < inner_left && (outer_left = max(outer_left, y))
		y > inner_right && (outer_right = min(outer_right, y))
    end
	if isfinite(inner_left) && isfinite(outer_left) && isfinite(inner_right) && isfinite(outer_right)
		# store the (z, approx slice width) pair in the recorder
		observation = (z, float((outer_right+inner_right)/2.0 - (outer_left + inner_left)/2.0))
        @record_if_requested!(replica.recorders, :slice_bounds, (key, observation))
    end
    # update the state and return the new cached lp
    pointer[] = new_x
    return new_lp
end

# generic case
function init_slice_endpoints(current, width, rng)
    L = current - width * rand(rng)
    R = L + width
    return (L, R)
end

# handle integers separately
function init_slice_endpoints(current::T, width, rng) where {T<:Integer}
	iwidth = ceil(T, width)
    L = current - rand(rng, 0:iwidth)
    R = L + iwidth
    return (L, R)
end

function slice_double!(t::SliceBoundsTrackingEvaluator, replica, x, w)
    rng = replica.rng
    L, R = init_slice_endpoints(x, w, rng)
    lp_L = lp_R = NaN
    cache = Float64[]
    while true
        expand_left = (rand(rng) <= 0.5)
        if isnan(lp_L) && isnan(lp_R)
    		@record_if_requested!(replica.recorders, :explorer_n_steps, (replica.chain, 1))
            if expand_left
                lp_R = tracked_slice_eval!(t, R)
            else
                lp_L = tracked_slice_eval!(t, L)
            end
        end
		if lp_L < t.z && isnan(lp_R)
    		@record_if_requested!(replica.recorders, :explorer_n_steps, (replica.chain, 1))
            lp_R = tracked_slice_eval!(t, R)
        end
        if lp_R < t.z && isnan(lp_L)
    		@record_if_requested!(replica.recorders, :explorer_n_steps, (replica.chain, 1))
            lp_L = tracked_slice_eval!(t, L)
        end
        if lp_L < t.z && lp_R < t.z
            return L, R, lp_L, lp_R, cache
        end
        if expand_left
            push!(cache, lp_L)
            L -= R - L
            lp_L = NaN
        else
            push!(cache, lp_R)
            R += R - L
            lp_R = NaN
        end
    end
end

draw_new_posn(L, R, rng) = L + rand(rng) * (R-L)
draw_new_posn(L::Integer, R::Integer, rng) = rand(rng, L:R)

function slice_shrink!(t::SliceBoundsTrackingEvaluator, replica, x, cached_lp, L, R, lp_L, lp_R, cache)
    curL, curR = L, R
    while true
        proposal = draw_new_posn(curL, curR, replica.rng)
    	@record_if_requested!(replica.recorders, :explorer_n_steps, (replica.chain, 1))
        lp = tracked_slice_eval!(t, proposal)
        if lp >= t.z && slice_accept!(t, replica, x, proposal, L, R, lp_L, lp_R, cache)
            return proposal, lp
        end
        if proposal < x
            curL = proposal
        else
            curR = proposal
        end
    end
end

function slice_accept!(t::SliceBoundsTrackingEvaluator, replica, x, proposal, L, R, lp_L, lp_R, cache)
    for j in length(cache):-1:1
    	# compute the midpoint
		midpoint = (L+R)/2
		# if x remains in the slice prior to the upcoming move, we can still use the cache
        use_cache = L <= x <= R
        if proposal < midpoint
            R = midpoint
            lp_R = use_cache ? cache[j] : NaN
        else
            L = midpoint
            lp_L = use_cache ? cache[j] : NaN
        end
        # try to skip evals; if we know one edge is in the slice, we can just continue
        if lp_L >= t.z || lp_R >= t.z
            continue
        end
        # we are forced to evaluate. Both lpR,lpL are unknown or < z
        # in the event that only one is known, the below will always cost 1 eval
        # in the event that both are unknown, it evaluates the edge that didn't move first
        if isnan(lp_L) && isnan(lp_R)
    		@record_if_requested!(replica.recorders, :explorer_n_steps, (replica.chain, 1))
            if proposal < midpoint
                lp_L = tracked_slice_eval!(t, L)
            else
                lp_R = tracked_slice_eval!(t, R)
            end
        end
        if lp_L < t.z && isnan(lp_R)
    		@record_if_requested!(replica.recorders, :explorer_n_steps, (replica.chain, 1))
            lp_R = tracked_slice_eval!(t, R)
        end
        if lp_R < t.z && isnan(lp_L)
    		@record_if_requested!(replica.recorders, :explorer_n_steps, (replica.chain, 1))
            lp_L = tracked_slice_eval!(t, L)
        end
        if lp_L < t.z && lp_R < t.z
            @record_if_requested!(replica.recorders, :explorer_acceptance_pr, (replica.chain, 0.0))
            return false
        end
    end
    @record_if_requested!(replica.recorders, :explorer_acceptance_pr, (replica.chain, 1.0))
    return true
end

struct LazySliceWidthRecorder
	observations::Dict{Tuple{Int,Int},Vector{Tuple{Float64,Float64}}}
end
slice_bounds() = LazySliceWidthRecorder(Dict{Tuple{Int,Int},Vector{Tuple{Float64,Float64}}}())
record!(recorder::LazySliceWidthRecorder, datum) = record!(recorder.observations, datum)
Base.empty!(recorder::LazySliceWidthRecorder) = empty!(recorder.observations)
function Base.merge(a::LazySliceWidthRecorder, b::LazySliceWidthRecorder)
	result = deepcopy(a.observations)
	#result = Dict{Tuple{Int,Int},Vector{Tuple{Float64,Float64}}}(key => copy(values) for (key, values) in a.observations)
    for (key, values) in b.observations
		append!(get!(result, key, Tuple{Float64,Float64}[]), values)
    end
    return LazySliceWidthRecorder(result)
end

explorer_recorder_builders(::LazySliceSampler) = [explorer_acceptance_pr, explorer_n_steps, slice_bounds]

function adapt_explorer(h::LazySliceSampler, reduced_recorders, current_pt, new_tempering)
    widths = copy(h.widths)
    for (key, observations) in reduced_recorders.slice_bounds.observations
        isempty(observations) && continue
        # Use a private, deterministic RNG so adaptation is reproducible and
        # does not consume any replica's random stream.
        samples = copy(observations)
        shuffle!(MersenneTwister(0), samples)
        resize!(samples, ceil(Int, length(samples)^0.95))
        sort!(samples, by = first)
        k = max(1, floor(Int, length(samples)^0.51))
        heights = Float64[]
        tuned = Float64[]
        for i in 1:k:length(samples)
            block = @view samples[i:min(i+k-1, length(samples))]
			lengths = [b[2] for b in block]
            width = 3 * quantile(lengths, 5 / (12 * log(2) + 5))
            if isfinite(width) && width > 0
                push!(heights, last(block)[1])
                push!(tuned, width)
            end
        end
        isempty(tuned) || (widths[key] = (heights, tuned))
    end
    return LazySliceSampler(h.w, h.n_passes, widths)
end
