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
Average MH swap acceptance probabilities for each pairs 
of interacting chains. 
"""
@provides recorder swap_acceptance_pr() = GroupBy(Tuple{Int, Int}, Mean())

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
"""
@provides recorder target_online() = OnlineStateRecorder() 


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
