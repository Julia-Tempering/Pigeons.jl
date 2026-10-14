"""
$SIGNATURES

Slice sampler operating coordinate-wise on whitened variables
`z = A⁻¹ (x - μ)`, where `A Aᵀ = Σ` and `μ`, `Σ` are the mean and the covariance
of the target estimated from the previous round. Updating `z[c]` moves the state
along the column `A[:, c]`, so that linear correlations in the target do not
slow down the exploration.

The whitening starts from the identity, so that the sampler initially behaves
as `SliceSampler(w = w)`. Starting from round `first_tuning_round`, at the end of
each round the mean and the covariance of the target chain(s) are used to
update the whitening, which is used from the following round on (the same
strategy used by [`GaussianReference`](@ref)).

Poor covariance estimates can make the exploration worse, which in turn makes
the following estimates worse. To prevent this, the whitening is only updated
when the effective number of samples of the round (estimated with Geyer's
initial monotone sequence, for the worst-mixing coordinate) is at least
`min_samples`; the correlations are shrunk toward zero according to the same
effective number of samples; and the scale along any direction can change at
most by a factor `max_scale_change` per round.

Only states that are (or wrap) vectors of `Float64` can be whitened.

Keyword arguments of the main constructor:

- `whitening`: `:full` (eigen-decomposition of a covariance shrunk toward its
  diagonal) or `:diagonal` (one scale per coordinate)
- the remaining keyword arguments set the homonymous fields described below.

Fields:
$FIELDS
"""
struct WhitenedSliceSampler{M<:AbstractMatrix{Float64}}
    """ Initial slice size, in whitened units (a few times the unit scale of whitened variables minimizes the number of log-density evaluations). """
    w::Float64

    """ Slices are no larger than 2^p * w """
    p::Int

    """ Number of passes through all variables per exploration step. """
    n_passes::Int

    """ Maximum number of interations inside shrink_slice! before erroring out """
    max_iter::Int

    """ First round whose samples are used for the whitening. """
    first_tuning_round::Int

    """ Minimum effective number of target samples in a round needed to update the whitening; otherwise, the previous whitening is retained. """
    min_samples::Int

    """ Maximum factor by which the scale along any direction can change in a single update. """
    max_scale_change::Float64

    """ Lower limit of the covariance eigenvalues (or variances), relative to the largest one. """
    eigen_floor::Float64

    """ Centre of the whitening transformation (empty for the identity). """
    μ::Vector{Float64}

    """ Matrix `A` with `A Aᵀ = Σ` (empty for the identity). """
    A::M

    """ Inverse of `A` (empty for the identity). """
    W::M

    function WhitenedSliceSampler(w, p, n_passes, max_iter, first_tuning_round,
            min_samples, max_scale_change, eigen_floor, μ, A::M, W::M) where {M}
        w > 0 || throw(ArgumentError("the slice width `w` must be positive"))
        first_tuning_round ≥ 1 ||
            throw(ArgumentError("`first_tuning_round` must be at least 1"))
        min_samples ≥ 2 || throw(ArgumentError("`min_samples` must be at least 2"))
        max_scale_change > 1 ||
            throw(ArgumentError("`max_scale_change` must be larger than one"))
        0 ≤ eigen_floor < 1 || throw(ArgumentError("`eigen_floor` must be in [0, 1)"))
        size(A) == size(W) == (length(μ), length(μ)) ||
            throw(DimensionMismatch("inconsistent whitening transformation"))
        new{M}(w, p, n_passes, max_iter, first_tuning_round, min_samples,
            max_scale_change, eigen_floor, μ, A, W)
    end
end

function WhitenedSliceSampler(;
        whitening::Union{Symbol,AbstractString} = :full,
        w::Real = 4.0,
        p::Integer = 20,
        n_passes::Integer = 3,
        max_iter::Integer = 1_024,
        first_tuning_round::Integer = 6,
        min_samples::Integer = 5,
        max_scale_change::Real = 10.0,
        eigen_floor::Real = 1e-12)
    identity =
        if Symbol(whitening) === :full
            zeros(0, 0)
        elseif Symbol(whitening) === :diagonal
            Diagonal(Float64[])
        else
            throw(ArgumentError("`whitening` must be `full` or `diagonal`, got `$whitening`"))
        end
    WhitenedSliceSampler(w, p, n_passes, max_iter, first_tuning_round, min_samples,
        max_scale_change, eigen_floor, Float64[], identity, identity)
end

# same explorer settings, new whitening transformation
WhitenedSliceSampler(h::WhitenedSliceSampler, μ, A, W) =
    WhitenedSliceSampler(h.w, h.p, h.n_passes, h.max_iter, h.first_tuning_round,
        h.min_samples, h.max_scale_change, h.eigen_floor, μ, A, W)

# the equivalent slice sampler, operating on whitened coordinates
slice_sampler(h::WhitenedSliceSampler) = SliceSampler(h.w, h.p, h.n_passes, h.max_iter)

is_identity(h::WhitenedSliceSampler) = isempty(h.μ)

"""
$SIGNATURES

Pointer-like object to the whitened coordinate `z[c]`, usable with the slice
sampler routines: setting it to `v` sets the state to
`base + (v - z₀) * A[:, c]`, where `base` and `z₀` are the state and the
coordinate value before the update.
"""
struct WhitenedCoordinate{S<:AbstractVector{Float64}, M}
    state::S
    base::Vector{Float64}
    z::Vector{Float64}
    A::M
    c::Int
    z₀::Float64
end

Base.getindex(r::WhitenedCoordinate) = @inbounds r.z[r.c]

function Base.setindex!(r::WhitenedCoordinate{<:Any, <:Matrix}, v)
    Δ = v - r.z₀
    c = r.c
    @inbounds r.z[c] = v
    @inbounds for i in eachindex(r.state)
        r.state[i] = muladd(Δ, r.A[i, c], r.base[i])
    end
    return v
end

function Base.setindex!(r::WhitenedCoordinate{<:Any, <:Diagonal}, v)
    c = r.c
    @inbounds r.z[c] = v
    @inbounds r.state[c] = muladd(v - r.z₀, r.A.diag[c], r.base[c])
    return v
end

### Dispatch on state for the behaviours for the different targets ###

step!(explorer::WhitenedSliceSampler, replica, shared) =
    step!(explorer, replica, shared, replica.state)

step!(explorer::WhitenedSliceSampler, replica, shared, state) =
    error("WhitenedSliceSampler only supports states that are vectors of Float64, " *
          "got $(typeof(state)); use SliceSampler instead.")

# note: as in slice_sample!, the log potential is evaluated on `replica.state`,
# `state` being the (possibly aliased) vector version of it
function step!(explorer::WhitenedSliceSampler, replica, shared, state::AbstractVector{Float64})
    log_potential = find_log_potential(replica, shared.tempering, shared)
    slicer = slice_sampler(explorer)
    if is_identity(explorer)
        cached_lp = -Inf
        for _ in 1:explorer.n_passes
            cached_lp = slice_sample!(slicer, state, log_potential, cached_lp, replica)
        end
    else
        whitened_slice_sample!(explorer, slicer, state, replica, log_potential)
    end
    if is_target(shared.tempering.swap_graphs, replica.chain)
        @record_if_requested!(replica.recorders, :whitened_slice_covariance,
            (replica.chain, shared.iterators.scan, state))
    end
end

function whitened_slice_sample!(explorer::WhitenedSliceSampler, slicer, state, replica,
        log_potential)
    dim = length(state)
    length(explorer.μ) == dim ||
        throw(DimensionMismatch("the whitening has dimension $(length(explorer.μ)), " *
                                "the state $dim"))
    base = get_buffer(replica.recorders.buffers, :whitened_slice_base_buffer, dim)
    z = get_buffer(replica.recorders.buffers, :whitened_slice_z_buffer, dim)
    @. base = state - explorer.μ
    mul!(z, explorer.W, base)
    cached_lp = cached_log_potential(log_potential, replica.state, -Inf)
    for _ in 1:explorer.n_passes
        for c in 1:dim
            copyto!(base, state)
            pointer = WhitenedCoordinate(state, base, z, explorer.A, c, z[c])
            cached_lp = slice_sample_coord!(slicer, replica, pointer, log_potential,
                cached_lp, Float64)
            # check we still have a healthy state
            if !isfinite(cached_lp)
                error("""Got an invalid log density after updating the whitened coordinate $c:
                - log density = $cached_lp
                - z[$c]       = $(z[c])
                Dumping full replica state:
                $(replica.state)
                """)
            end
        end
    end
    return cached_lp
end

"""
$SIGNATURES

Recorder of the states of the target chain(s), indexed by `(chain, scan)`, used
by [`WhitenedSliceSampler`](@ref) to estimate the mean, the covariance, and the
effective number of samples of the target. Since replicas swap chains, the
states of a target chain are spread over the recorders of different replicas:
merging them and sorting by key reassembles each chain in scan order.

The states are stored in flat vectors that retain their capacity when the
recorder is emptied, so that recording is allocation-free after the first round.
"""
mutable struct TargetStateRecorder
    dim::Int
    keys::Vector{Tuple{Int,Int}}
    states::Vector{Float64}
end

TargetStateRecorder() = TargetStateRecorder(0, Tuple{Int,Int}[], Float64[])

"""
States of the target chain(s), used by [`WhitenedSliceSampler`](@ref) to
adapt the whitening.
"""
@provides recorder whitened_slice_covariance() = TargetStateRecorder()

function record!(recorder::TargetStateRecorder, datum::Tuple{Integer,Integer,AbstractVector})
    chain, scan, x = datum
    if isempty(recorder.keys)
        recorder.dim = length(x)
    elseif length(x) ≠ recorder.dim
        throw(DimensionMismatch("recorded states of dimension $(length(x)) and $(recorder.dim)"))
    end
    push!(recorder.keys, (Int(chain), Int(scan)))
    append!(recorder.states, x)
    return recorder
end

Base.merge(a::TargetStateRecorder, b::TargetStateRecorder) =
    TargetStateRecorder(isempty(a.keys) ? b.dim : a.dim, vcat(a.keys, b.keys), vcat(a.states, b.states))

function Base.empty!(recorder::TargetStateRecorder)
    empty!(recorder.keys)
    empty!(recorder.states)
    return recorder
end

nsamples(recorder::TargetStateRecorder) = length(recorder.keys)

"""
$SIGNATURES

Return the matrix of the recorded states (one column per sample), sorted by
chain and scan, and the ranges of columns corresponding to each chain.
"""
function ordered_states(recorder::TargetStateRecorder)
    order = sortperm(recorder.keys)
    X = reshape(recorder.states, recorder.dim, :)[:, order]
    ranges = UnitRange{Int}[]
    start = 1
    for k in 2:length(order) + 1
        if k > length(order) || recorder.keys[order[k]][1] ≠ recorder.keys[order[k - 1]][1]
            push!(ranges, start:k - 1)
            start = k
        end
    end
    return X, ranges
end

"""
$SIGNATURES

Mean and covariance of the samples in the columns of `X`.
"""
function sample_moments(X::AbstractMatrix)
    n = size(X, 2)
    μ = vec(sum(X; dims = 2)) ./ n
    Xc = X .- μ
    return μ, (Xc * Xc') ./ (n - 1)
end

"""
$SIGNATURES

Integrated autocorrelation time `τ` of the series `x`, estimated with Geyer's
initial monotone sequence: the sums of pairs of consecutive autocorrelations
`ρ₂ₘ + ρ₂ₘ₊₁` are summed while positive, and forced to be non-increasing. The
autocorrelations are computed directly, up to the lag where the sequence stops.
"""
function integrated_autocorrelation(x::AbstractVector)
    n = length(x)
    μ = sum(x) / n
    autocovariance(k) = sum((x[t] - μ) * (x[t + k] - μ) for t in 1:n - k; init = 0.0) / n
    c₀ = autocovariance(0)
    c₀ > 0 || return Inf
    τ = -1.0
    previous = Inf
    for m in 0:(n - 2) ÷ 2
        Γ = (autocovariance(2m) + autocovariance(2m + 1)) / c₀
        Γ > 0 || break
        Γ = min(Γ, previous)
        τ += 2Γ
        previous = Γ
    end
    return max(τ, 1 / n)
end

"""
$SIGNATURES

Effective number of independent samples in the recorder: for each coordinate,
the sum over the target chains of their length divided by the integrated
autocorrelation time; the minimum over the coordinates is returned.
"""
effective_samples(recorder::TargetStateRecorder) = effective_samples(ordered_states(recorder)...)

function effective_samples(X::AbstractMatrix, ranges)
    n_eff = Inf
    series = Vector{Float64}(undef, size(X, 2))
    for i in axes(X, 1)
        total = 0.0
        for range in ranges
            length(range) ≥ 4 || continue
            x = view(series, 1:length(range))
            x .= view(X, i, range)
            total += min(length(range) / integrated_autocorrelation(x), length(range))
        end
        n_eff = min(n_eff, total)
    end
    return isfinite(n_eff) ? n_eff : 0.0
end

explorer_recorder_builders(::WhitenedSliceSampler) =
    [explorer_acceptance_pr, explorer_n_steps, buffers, whitened_slice_covariance]

function adapt_explorer(explorer::WhitenedSliceSampler, reduced_recorders, current_pt,
        new_tempering)
    round = current_pt.shared.iterators.round
    round ≥ explorer.first_tuning_round || return explorer
    haskey(reduced_recorders, :whitened_slice_covariance) || return explorer
    whitening = estimate_whitening(explorer, reduced_recorders.whitened_slice_covariance;
        round)
    whitening === nothing && return explorer
    return WhitenedSliceSampler(explorer, whitening...)
end

"""
$SIGNATURES

Return the tuple `(μ, A, W)` estimated from the `recorder`, or `nothing`
for unreliable or degenerate estimates (too few effective samples, non-finite
values, or coordinates that never moved): in that case the current whitening
should be retained.
"""
function estimate_whitening(explorer::WhitenedSliceSampler, recorder::TargetStateRecorder;
        round = 0)
    n = nsamples(recorder)
    n ≥ explorer.min_samples || return nothing
    all(isfinite, recorder.states) || return nothing
    X, ranges = ordered_states(recorder)
    μ, Σ = sample_moments(X)
    variances = [Σ[i, i] for i in axes(Σ, 1)]
    all(>(0), variances) || return nothing
    n_eff = effective_samples(X, ranges)
    if n_eff < explorer.min_samples
        @debug "WhitenedSliceSampler: whitening not updated" round n n_eff
        return nothing
    end
    Σ̂, λ = shrink_covariance(explorer.A, Σ, variances, n_eff)
    Σ̂, clamped = limit_change(explorer, Σ̂)
    @debug "WhitenedSliceSampler: whitening updated" round n n_eff λ clamped
    matrices = whitening_matrices(Σ̂, explorer.eigen_floor)
    matrices === nothing && return nothing
    return (μ, matrices...)
end

# only the variances are used for the diagonal whitening
shrink_covariance(::Diagonal, _, variances, _) = (Diagonal(variances), 1.0)

# shrink the correlations toward zero (Schäfer & Strimmer 2005, target "D"), using the
# Gaussian approximation Var(rᵢⱼ) ≈ (1 - rᵢⱼ²)² / (n_eff - 1)
function shrink_covariance(::Matrix, Σ, variances, n_eff)
    σ = sqrt.(variances)
    numerator = denominator = 0.0
    for j in axes(Σ, 2), i in axes(Σ, 1)
        if i ≠ j
            r² = (Σ[i, j] / (σ[i] * σ[j]))^2
            numerator += (1 - min(r², 1.0))^2 / (n_eff - 1)
            denominator += r²
        end
    end
    λ = denominator > 0 ? clamp(numerator / denominator, 0.0, 1.0) : 1.0
    shrunk = Σ .* (1 - λ)
    for i in axes(Σ, 1)
        shrunk[i, i] = Σ[i, i]
    end
    return (shrunk, λ)
end

"""
$SIGNATURES

Limit the change of the scales with respect to the current whitening: the
eigenvalues of `Σ` in the current whitened coordinates are clamped to
`[1/κ², κ²]`, with `κ = explorer.max_scale_change`. Return the clamped matrix
and the number of clamped directions.
"""
function limit_change(explorer::WhitenedSliceSampler, Σ::Diagonal)
    κ² = explorer.max_scale_change^2
    old = is_identity(explorer) ? ones(size(Σ, 1)) : explorer.A.diag .^ 2
    ratios = Σ.diag ./ old
    clamped = count(r -> !(1 / κ² ≤ r ≤ κ²), ratios)
    return (Diagonal(old .* clamp.(ratios, 1 / κ², κ²)), clamped)
end

function limit_change(explorer::WhitenedSliceSampler, Σ::Matrix)
    κ² = explorer.max_scale_change^2
    S = is_identity(explorer) ? Σ : explorer.W * Σ * explorer.W'
    F = eigen(Symmetric(S))
    clamped = count(v -> !(1 / κ² ≤ v ≤ κ²), F.values)
    L = F.vectors .* sqrt.(clamp.(F.values, 1 / κ², κ²))'
    is_identity(explorer) || (L = explorer.A * L)
    return (L * L', clamped)
end

function whitening_matrices(Σ::Diagonal, eigen_floor)
    floor = eigen_floor * maximum(Σ.diag)
    scales = sqrt.(max.(Σ.diag, floor))
    return (Diagonal(scales), Diagonal(inv.(scales)))
end

function whitening_matrices(Σ::Matrix, eigen_floor)
    F = eigen(Symmetric(Σ))
    largest = maximum(F.values)
    (isfinite(largest) && largest > 0) || return nothing
    scales = sqrt.(max.(F.values, eigen_floor * largest))
    A = F.vectors .* scales'
    W = Matrix((F.vectors ./ scales')')
    return (A, W)
end
