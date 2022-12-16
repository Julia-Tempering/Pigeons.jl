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
After a PT round, use [`reduced_recorders!()`](@ref) to do 
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
    function record_if_requested!(recorders::NamedTuple, recorder_key, value)
        if haskey(recorders, recorder_key)
            record!(recorders[recorder_key], value)
        end
    end
end

"""
$(TYPEDSIGNATURES)

Basic, constant-memory [`recorders`](@ref).
"""
@provides recorders default_recorders() = (;
        swap_acceptance_pr = GroupBy(Tuple{Int, Int}, Mean()),
    )

"""
$(TYPEDSIGNATURES)

This returns [`default_recorders()`](@ref) plus those 
provided in the `recorder_keys`. 

See also [`recorder_keys`](@ref).
"""
@provides recorders function custom_recorders(recorder_keys::Set{Symbol}) 
    result = default_recorders()
    if :index_process in recorder_keys
        result = merge(result, (; index_process = Dict{Int, Vector{Int}}()))
    end
    return result
end

"""
$TYPEDSIGNATURES

This returns a fresh [`recorders`](@ref) with the same recorder_keys as the provided 
[`recorders`](@ref).
"""
@provides recorders empty_recorders(recorders) = custom_recorders(Set(keys(recorders)))

"""
$(TYPEDSIGNATURES)
Some statistics may induce memory requirements growing in 
the number of iterations. Use this to select which ones, 
if any to pass to [`custom_recorders()`](@ref).
E.g.: `recorder_keys()` or `recorder_keys(:index_process)`.

Choices include (each specifying if it is included 
in [`default_recorders()`](@ref)):

- `:swap_acceptance_pr`: maintain swap acceptance probabilities,
    a `GroupBy(Tuple{Int, Int}, Mean())` object
    (included by default);
- `:index_process`: keep, for each replica, the list of 
    chains visited (not included by default), a 
    `Dict{Int, Vector{Int}}` object.

"""
recorder_keys(args::Symbol...) = Set(args)

"""
$TYPEDSIGNATURES

Perform a reduction across all the replicas' individual recorders, 
using  [`combine!()`](@ref) on each individual [`recorder`](@ref)
held. 
Returns a [`recorders`](@ref) with all the information merged. 

Will reset the replicas' recorders at the same time. 

Since this uses [`all_reduce_deterministically`](@ref), the output is 
identical, no matter how many MPI processes are used, even when 
the reduction involves only approximately associative [`combine!()`](@ref)
operations (e.g. most floating point ones).
"""
reduced_recorders!(replicas) = all_reduce_deterministically(merge_recorders!, _recorders.(locals(replicas)), entangler(replicas))

function merge_recorders!(recorders1, recorders2)
    shared_keys = keys(recorders1)
    @assert shared_keys == keys(recorders2)

    values1 = values(recorders1)
    values2 = values(recorders2)
    merged_values = [combine!(values1[i], values2[i]) for i in eachindex(values1)]
    return (; zip(shared_keys, merged_values)...)
end