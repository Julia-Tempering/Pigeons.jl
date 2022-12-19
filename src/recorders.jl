"""
A `NamedTuple` containing several [`recorder`](@ref)'s. 
Each recorder is responsible for a type of statistic to be 
accumulated. 

The keyset of the NamedTuple controls which types of 
statistics to accumulate (we refer to each element in 
this keyset as a `recorder_key`). By default, only those 
with constant memory requirement are selected, the user 
can select more expensive ones by enlarging that keyset.

During PT execution, each recorders object keep track of only the 
statistics for one replica (for thread safety and/or 
distribution purpose).
After a PT round, use [`reduce_recorders!()`](@ref) to do 
a [reduction](https://en.wikipedia.org/wiki/MapReduce) before 
accessing statistic values. 
"""
@informal recorders begin 
    """
    $TYPEDSIGNATURES

    If the [`recorders`](@ref) contains the given `recorder_key`, 
    send the `value` to the [`recorder`](@key) corresponding to the 
    `recorder_key`. Otherwise, do nothing.
    """
    function record_if_requested!(recorders::NamedTuple, recorder_key::Symbol, context::RecordContext, value)
        if haskey(recorders, recorder_key)
            record!(recorders[recorder_key], context, value)
        end
    end
end

"""
$(TYPEDSIGNATURES)

Constant-memory [`recorders`](@ref).
"""
@provides recorders default_recorders() = (;
        swap_acceptance_pr = GroupBy(Tuple{Int, Int}, Mean()),
        check_point = CheckPointRecorder(), 
    )

"""
$(TYPEDSIGNATURES)

Non-constant-memory [`recorders`](@ref).
"""
expensive_recorders() = (;
    index_process = Dict{Int, Vector{Int}}(),
)

"""
$(TYPEDSIGNATURES)

This returns all of [`default_recorders()`](@ref) plus 
the subset of 
[`expensive_recorders()`](@ref) for which the key is 
provided in the `recorder_keys`. 
"""
@provides recorders function custom_recorders(recorder_keys) 
    result = default_recorders()
    return merge(result, slice_tuple(expensive_recorders(), recorder_keys))
end

"""
$(TYPEDSIGNATURES)

Returns all the default recorder plus all 
the [`expensive_recorders()`](@ref).
"""
@provides recorders function all_recorders()
    return merge(default_recorders(), expensive_recorders())
end

"""
$TYPEDSIGNATURES

Perform a reduction across all the replicas' individual recorders, 
using [`combine!()`](@ref) on each individual [`recorder`](@ref)
held. 
Returns a [`recorders`](@ref) with all the information merged. 

Will reset the replicas' recorders at the same time. 

Since this uses [`all_reduce_deterministically`](@ref), the output is 
identical, no matter how many MPI processes are used, even when 
the reduction involves only approximately associative [`combine!()`](@ref)
operations (e.g. most floating point ones).
"""
reduce_recorders!(replicas) = 
    all_reduce_deterministically(
        merge_recorders!, 
        _recorders.(locals(replicas)), 
        entangler(replicas))

function merge_recorders!(recorders1, recorders2)
    shared_keys = keys(recorders1)
    @assert shared_keys == keys(recorders2)

    values1 = values(recorders1)
    values2 = values(recorders2)
    merged_values = [combine!(values1[i], values2[i]) for i in eachindex(values1)]
    return (; zip(shared_keys, merged_values)...)
end