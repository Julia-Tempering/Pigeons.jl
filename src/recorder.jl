"""
Accumulate a specific type of statistic, for example 
by keeping constant size sufficient statistics 
(via `OnlineStat`, which conforms this interface), 
storing samples to a file, etc. 
See also [`recorders`](@ref).
"""
@informal recorder begin
    """
    $(TYPEDSIGNATURES)

    Add `value` to the statistics accumulated by [`recorder`](@ref).
    """
    record!(recorder, value) = @abstract 

    """
    $(TYPEDSIGNATURES)

    Combine the two provided [`recorder`](@ref) objects. 

    By default, call `Base.merge()`.
    """
    combine(recorder1, recorder2) = merge(recorder1, recorder2)
end

"""
$TYPEDSIGNATURES

Forwards to OnlineStats' `fit!`
"""
record!(recorder::OnlineStat, value) = fit!(recorder, value)

"""
$TYPEDSIGNATURES

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


