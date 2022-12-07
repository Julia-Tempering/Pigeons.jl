"""
Statistics in the process of being collected, in particular, 
    they have not been reduced yet. Use reduced_stats(..) to do the reduction.
"""

empty_recorder() = (;
        swap_acceptance_pr = GroupBy(Int, Mean())
    )

function fit_if_defined!(stats_tuple, key, value)
    if haskey(stats_tuple, key)
        fit!(stats_tuple[key], value)
    end
end

reduced_stats(replicas) = all_reduce_deterministically(merge_stat_tuple, recorder.(locals(replicas)), entangler(replicas))

function merge_stat_tuple(stat1, stat2)
    shared_keys = keys(stat1)
    @assert shared_keys == keys(stat2)
    values1 = values(stat1)
    values2 = values(stat2)
    merged_values = [merge(values1[i], values2[i]) for i in eachindex(values1)]
    return (; zip(shared_keys, merged_values)...)
end

