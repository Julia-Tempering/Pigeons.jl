"""
Statistics in the process of being collected, in particular, 
    they have not been reduced yet. Use reduced_stats(..) to do the reduction.
"""

empty_recorder() = (;
        swap_acceptance_pr = GroupBy(Int, Mean())
    )

"""
$TYPEDSIGNATURES
"""
function fit_if_defined!(stats_tuple, key, value)
    if haskey(stats_tuple, key)
        fit!(stats_tuple[key], value)
    end
end

#=
- recorders: tuple: recorderKey -> recorder
- recorder
    signatures:
        record(r, ...)
        merge(r1, r2)

    impls:
        OnlineStat for in-memory
        some kind of on-disk (work_dir + shared_dir), for check-point and large stats
    
=#

"""
$TYPEDSIGNATURES
"""
reduced_stats(replicas) = all_reduce_deterministically(merge_recorders, recorder.(locals(replicas)), entangler(replicas))

function merge_recorders(recorder1, recorder2)
    shared_keys = keys(recorder1)
    @assert shared_keys == keys(recorder2)

    values1 = values(recorder1)
    values2 = values(recorder2)
    merged_values = [merge(values1[i], values2[i]) for i in eachindex(values1)]
    return (; zip(shared_keys, merged_values)...)
end



