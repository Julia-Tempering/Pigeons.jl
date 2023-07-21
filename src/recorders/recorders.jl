"""
A `NamedTuple` containing several [`recorder`](@ref)'s. 
Each recorder is responsible for a type of statistic to be 
accumulated (e.g. one for swap accept prs, one for round trip 
info; some are in-memory, some are on file). 

During PT execution, each recorders object keep track of only the 
statistics for one replica (for thread safety and/or 
distribution purpose).
After a PT round, [`reduce_recorders!()`](@ref) is used to do 
a [reduction](https://en.wikipedia.org/wiki/MapReduce) before 
accessing statistic values. 
"""
@informal recorders begin 
    """
    $SIGNATURES

    If the [`recorders`](@ref) contains the given `recorder_key`, 
    send the `value` to the [`recorder`](@ref) corresponding to the 
    `recorder_key`. Otherwise, do nothing.

    When `value` is costly or may cause allocation,
    use [`@record_if_requested!()`](@ref) instead.
    """
    function record_if_requested!(recorders, recorder_key::Symbol, value)
        if !isnothing(recorders) && haskey(recorders, recorder_key)
            record!(recorders[recorder_key], value)
        end
    end
end

"""
$(SIGNATURES)

Create a [`recorders`](@ref) from an [`Inputs`](@ref) and [`Shared`](@ref).
"""
@provides recorders create_recorders(inputs::Inputs, shared::Shared) =
    create_recorders(recorder_builders(inputs, shared)) 

"""
$(SIGNATURES)

Create a [`recorders`](@ref) from an iterable with element 
type [`recorder_builder`](@ref).
"""
@provides recorders function create_recorders(recorder_builders) 
    tuple_keys = Symbol[]
    tuple_values = Any[]
    for recorder_builder in recorder_builders
        push!(tuple_keys,   Symbol(recorder_builder))
        push!(tuple_values, recorder_builder())
    end
    return (; zip(tuple_keys, tuple_values)...)

end

"""
A function such that calling it returns a fresh 
[`recorder`](@ref).
"""
@informal recorder_builder begin end

function recorder_builders(inputs::Inputs, shared::Shared)
    result = OrderedSet{Function}()
    union!(result, explorer_recorder_builders(shared.explorer))
    union!(result, tempering_recorder_builders(shared.tempering))
    union!(result, inputs.record)
    union!(result, variational_recorder_builders(inputs.variational))
    return result
end


"""
$SIGNATURES

Perform a reduction across all the replicas' individual recorders, 
using `Base.merge()` on each individual [`recorder`](@ref)
held.
Returns a [`recorders`](@ref) with all the information merged. 

Will reset the replicas' recorders at the same time using `Base.empty!()`.

Since this uses [`all_reduce_deterministically`](@ref), the output is 
identical, no matter how many MPI processes are used, even when 
the reduction involves only approximately associative `Base.merge()`
operations (e.g. most floating point ones).
"""
reduce_recorders!(pt, replicas::EntangledReplicas) = _reduce_recorders!(pt, replicas)

function reduce_recorders!(pt, replicas::Vector)
    sort!(replicas, by = r -> r.replica_index)
    result = _reduce_recorders!(pt, replicas)
    sort_replicas!(replicas)
    return result
end

function _reduce_recorders!(pt, replicas)
    result = 
        if entangler(replicas).load.n_global_indices == 1 
            # corner case: only one replica; 
            # without this we would erase right away the returned value 
            # Want to make a copy in that case. 
            @assert length(replicas) == 1
            recorders = replicas[1].recorders
            empty = create_recorders(recorder_builders(pt.inputs, pt.shared))
            merge_recorders(recorders, empty)
        else
            all_reduce_deterministically(
                merge_recorders, 
                _recorders.(locals(replicas)), 
                entangler(replicas)) 
        end

    for replica in locals(replicas)
        for recorder in values(replica.recorders)
            empty!(recorder)
        end
    end
    return result
end

function merge_recorders(recorders1, recorders2)
    shared_keys = keys(recorders1)
    @assert shared_keys == keys(recorders2)

    values1 = values(recorders1)
    values2 = values(recorders2)
    merged_values = [merge(values1[i], values2[i]) for i in eachindex(values1)]
    return (; zip(shared_keys, merged_values)...)
end