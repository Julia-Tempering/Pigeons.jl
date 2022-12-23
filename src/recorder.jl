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
    See [`RecordContext`](@ref) for accessing iteration indices, 
    output folders, etc.
    """
    record!(recorder, context::RecordContext, value) = @abstract 

    """
    $(TYPEDSIGNATURES)

    Combine the two provided [`recorder`](@ref) objects, and then 
    "dispose" of the two input arguments. 

    At a high-level, we dispose to avoid the same statistic being 
    counted twice. 

    More precisely, for an in-memory recorder, we "empty!" the input arguments to 
    ensure, e.g., that in the next PT round we start collecting statistics 
    from scratch. For file-based recorders, disposing means erasing 
    intermediate files that are no longer needed. 

    By default, call `Base.merge()` followed by `Base.empty!()`
    """
    function combine!(recorder1, recorder2) 
        result = merge(recorder1, recorder2)
        empty!(recorder1)
        empty!(recorder2)
        return result
    end
end

""" Average MH swap acceptance probabilities for each pairs of interacting chains. """
@provides recorder swap_acceptance_pr() = GroupBy(Tuple{Int, Int}, Mean())

""" Snapshot saved to file to reproduce/restart intermediate computations. """
@provides recorder check_point()        = CheckPointRecorder()

""" Full index process stored in memory. """
@provides recorder index_process()      = Dict{Int, Vector{Int}}()



function Base.empty!(x::Mean) 
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
$TYPEDSIGNATURES

Forwards to OnlineStats' `fit!`
"""
record!(recorder::OnlineStat, ::RecordContext, value) = fit!(recorder, value)

"""
$TYPEDSIGNATURES

Given a `value`, a pair `(a, b)`, and a `Dict{K, Vector{V}}` backed 
[`recorder`](@ref), 
append `b` to the vector corresponding to `a`, inserting an empty 
vector into the dictionary first if needed.
"""
function record!(recorder::Dict{K, Vector{V}}, ::RecordContext, value::Tuple{K, V}) where {K, V}
    a, b = value
    if !haskey(recorder, a)
        recorder[a] = Vector{V}()
    end
    push!(recorder[a], b)
end

"""
A [`recorder`](@ref) storing a checkpoint in the filesystem. 
"""
struct CheckPointRecorder end

combine!(cp::CheckPointRecorder, ::CheckPointRecorder) = cp
Base.empty!(::CheckPointRecorder) = nothing

function record!(::CheckPointRecorder, context::RecordContext, value::Replica)  
    replica_output = output_file(context, "checkpoints/round=$(context.round)/replica=$(value.replica_index).jls")
    serialize(replica_output, value)
    if context.load.my_process_index == 1
        immutable_output = output_file(context, "checkpoints/immutables.jls")
        if !isfile(immutable_output)
            serialize_immutables(immutable_output)
        end
    end
end




