"""
Accumulate a specific type of statistic, for example 
by keeping constant size sufficient statistics 
(via `OnlineStat`, which conforms this interface), 
storing samples to a file, etc. 

In addition to the contract below, a recorder should support 
- `Base.merge()`
- `Base.empty!()`

See also [`recorders`](@ref).
"""
@informal recorder begin
    """
    $SIGNATURES

    Add `value` to the statistics accumulated by [`recorder`](@ref). 
    """
    record!(recorder, value) = @abstract 
end

"""
Save the full trace for the target chain in memory. 
Call copy() on each state on the target chain. Index them by 
the (chain index, scan index). 
"""
@provides recorder traces() = Dict{Pair{Int, Int}, Any}() 

"""
Save the full trace for the target chain to disk. 

The `disk` recorders are safe to use in a multi-threaded and/or 
distributed context as each replica uses its own file.

To post-process files in the correct order, use [`process_sample`](@ref).
"""
@provides recorder disk() = DiskRecorder() 

function record!(traces::Dict{Pair{Int, Int}, T}, datum) where {T}
    key = datum.chain => datum.scan 
    @assert !haskey(traces, key) 
    traces[key] = datum.contents # copy is called if needed by caller in pigeons.jl/explore!()
end

""" 
Average MH swap acceptance probabilities for each pairs 
of interacting chains. 
"""
@provides recorder swap_acceptance_pr() = GroupBy(Tuple{Int, Int}, Mean())

function swap_prs(pt)
    collection = value(pt.reduced_recorders.swap_acceptance_pr)
    return value.(values(collection))
end

""" 
Average MH swap acceptance probabilities for explorers.  
"""
@provides recorder explorer_acceptance_pr() = GroupBy(Int, Mean())

function explorer_mh_prs(pt)
    collection = value(pt.reduced_recorders.explorer_acceptance_pr)
    return value.(values(collection))
end

""" 
Number of steps used by explorers.
"""
@provides recorder explorer_n_steps() = GroupBy(Int, Sum())

function explorer_n_steps(pt)
    collection = value(pt.reduced_recorders.explorer_n_steps)
    return value.(values(collection))
end

""" 
Full index process stored in memory. 
"""
@provides recorder index_process() = Dict{Int, Vector{Int}}()

""" 
Log of the sum of density ratios between neighbour chains, used 
to compute stepping stone estimators of lognormalization contants.
"""
@provides recorder log_sum_ratio() = GroupBy(Tuple{Int, Int}, LogSum())

""" 
Online statistics on the target chain. 
The samples are processed in the original model parameterization.
"""
@provides recorder online() = OnlineStateRecorder() 

""" 
Online statistics on potentially transformed samples for the target chain. 
For example, if a gradient-based method is used, the target is often 
transformed to be defined on an unconstrained space. 
This is used internally by [`explorer`](@ref)'s for adaptation purposes 
(in particular, pre-conditioning and variational references).
"""
@provides recorder _transformed_online() = OnlineStateRecorder() 

""" 
Restart and round-trip counts. 
"""
@provides recorder round_trip() = RoundTripRecorder() 

""" 
Auto-correlation before and after an exploration step, grouped by  
chain.
"""
@provides recorder energy_ac1() = GroupBy(Int, CovMatrix(2))

""" 
Timing informations. 
"""
@provides recorder timing_extrema() = NonReproducible(GroupBy(Symbol, Extrema()))

""" 
Allocations informations. 
"""
@provides recorder allocation_extrema() = NonReproducible(GroupBy(Symbol, Extrema()))

record_timed_if_requested!(pt::PT, category::Symbol, timed) = 
record_timed_if_requested!(locals(pt.replicas)[1].recorders, category, timed)

function record_timed_if_requested!(recorders, category::Symbol, timed)
    @record_if_requested!(recorders, :timing_extrema,     (category, timed.time))
    @record_if_requested!(recorders, :allocation_extrema, (category, timed.bytes))
end


"""
Maximum time (over the MPI process) to compute the last Parallel Tempering round. 
"""
last_round_max_time(pt)  = maximum(value(pt.reduced_recorders.timing_extrema.contents)[:round])

"""
Maximum bytes allocated (over the MPI process) to compute the last Parallel Tempering round. 
"""
last_round_max_allocation(pt) = maximum(value(pt.reduced_recorders.allocation_extrema.contents)[:round])


"""
$SIGNATURES 

Auto-correlations between energy before and after an exploration step, 
for each chain. Organized as a `Vector` where component i corresponds 
to chain i.

It is often useful to skip the reference chain, for two reasons, first, 
exploration should be iid there, second, if the prior is flat the 
auto-correlation of the energy will be NaN for the reference.
"""
energy_ac1s(pt::PT, skip_reference = false) = energy_ac1s(pt.reduced_recorders, skip_reference, pt)


"""
$SIGNATURES
"""
function energy_ac1s(reduced_recorders, skip_reference = false, pt = nothing)
    stat = reduced_recorders.energy_ac1
    coll = value(stat)
    indices = 1:length(coll)
    if skip_reference
        indices = filter(indices) do chain 
            !is_reference(pt.shared.tempering.swap_graphs, chain) 
        end
    end
    return [cor(coll[i])[1,2] for i in indices]
end

function Base.empty!(x::Mean) 
    x.μ = zero(x.μ)
    x.n = zero(x.n)
    return x
end

function Base.empty!(x::Variance)
    x.σ2 = zero(x.σ2) 
    x.μ = zero(x.μ)
    x.n = zero(x.n) 
    return x 
end

function Base.empty!(x::GroupBy)
    x.n = zero(x.n)
    empty!(x.value)
    return x
end

function Base.empty!(o::CovMatrix{T}) where {T} 
    o.n = zero(o.n)
    z   = zero(T)
    fill!(o.b, z)
    fill!(o.A, z)
    fill!(o.value, z) 
    return o
end

"""
$SIGNATURES

Forwards to OnlineStats' `fit!`.
"""
record!(recorder::OnlineStat, value) = fit!(recorder, value)

"""
$SIGNATURES

Given a `value`, a pair `(a, b)`, and a `Dict{K, Vector{V}}` backed 
[`recorder`](@ref), 
append `b` to the vector corresponding to `a`, inserting an empty 
vector into the dictionary first if needed.
"""
function record!(recorder::Dict{K, Vector{V}}, value::Tuple{K, V}) where {K, V}
    a, b = value
    if !haskey(recorder, a)
        recorder[a] = Vector{V}()
    end
    push!(recorder[a], b)
end
