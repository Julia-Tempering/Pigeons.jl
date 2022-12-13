"""
A `NamedTuple` containing [`recorder`](@ref)'s. 
Each recorder is responsible for a type of statistic to be 
accumulated. 

The keyset of the NamedTuple controls which types of 
statistics to accumulate (we refer to each element in 
this keyset as a recorder_key). By default, only those 
with constant memory requirement are selected, the user 
can select more expensive ones by enlarging that keyset.

During PT execution, each recorders object keep track of only the 
statistics for one replica (for thread safety and/or 
distribution purpose).
After a PT round, use [`reduced_recorder()`](@ref) to do 
a [reduction](https://en.wikipedia.org/wiki/MapReduce) before 
accessing statistic values. 
"""
@informal recorders begin 
    """
    $TYPEDSIGNATURES
    If the [`recorders`](@ref) contains the given `recorder_key`, 
    send the `value` to the [`recorder`](@key) corresponding to the 
    `recorder_key`.
    """
    function record!(recorders, recorder_key, value)
        if haskey(recorders, recorder_key)
            record!(recorders[recorder_key], value)
        end
    end
end

"""
$(TYPEDSIGNATURES)
Basic, constant-memory recorders.
"""
@provides recorders default_recorders() = (;
        swap_acceptance_pr = GroupBy(Int, Mean()),
    )

"""
$(TYPEDSIGNATURES)
This returns `default_recorders()`[@ref] plus those 
provided in the `recorder_keys`.  
"""
@provides recorders function custom_recorders(recorder_keys::Set{Symbol}) 
    result = default_recorders()
    if :index_process in recorder_keys
        result = merge(result, (; index_process = Dict{Int, Vector{Int}}()))
    end
    return result
end

"""
$(TYPEDSIGNATURES)
Some statistics may induce memory requirements growing in 
the number of iterations. Use this to select which ones, 
if any to pass to [`custom_recorders()`](@ref).
E.g.: `recorder_keys()` or `recorder_keys(:index_process)`.
"""
recorder_keys(args::Symbol...) = Set(args)

"""
$TYPEDSIGNATURES
"""
reduced_recorder(replicas) = all_reduce_deterministically(merge_recorders, _recorders.(locals(replicas)), entangler(replicas))

function merge_recorders(recorders1, recorders2)
    shared_keys = keys(recorders1)
    @assert shared_keys == keys(recorders2)

    values1 = values(recorders1)
    values2 = values(recorders2)
    merged_values = [combine(values1[i], values2[i]) for i in eachindex(values1)]
    return (; zip(shared_keys, merged_values)...)
end