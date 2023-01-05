"""
A container for several types of [`recorder`](@ref)'s. 
Each recorder is responsible for a type of statistic to be 
accumulated (e.g. one for swap accept prs, one for round trip 
info; some are in-memory, some are on file). 

During PT execution, each recorders object keep track of only the 
statistics for one replica (for thread safety and/or 
distribution purpose).
After a PT round, [`reduce_recorders!()`](@ref) is used to do 
a [reduction](https://en.wikipedia.org/wiki/MapReduce) before 
accessing statistic values. 

Fields:
$FIELDS
"""
@concrete struct Recorders
    """
    A `NamedTuple` containing several [`recorder`](@ref)'s. 
    """
    contents

    """
    The [`Shared`](@ref) instance, passed to the 
    [`recorder`](@ref)'s so that they can refer to 
    round index, etc.
    """
    shared
end

"""
$(TYPEDSIGNATURES)

Create a [`Recorders`](@ref). 
"""
function Recorders(shared::Shared) 
    tuple_keys = Symbol[]
    tuple_values = Any[]
    for recorder_builder in recorder_builders(shared)
        push!(tuple_keys,   Symbol(recorder_builder))
        push!(tuple_values, recorder_builder())
    end
    tuple = (; zip(tuple_keys, tuple_values)...)
    return Recorders(tuple, shared)
end

function recorder_builders(shared::Shared)
    result = Set{Function}()
    union!(result, recorder_builders(shared.explorer))
    union!(result, recorder_builders(shared.temperer))
    union!(result, shared.inputs.recorder_builders)
    return result
end

"""
$TYPEDSIGNATURES

If the [`recorders`](@ref) contains the given `recorder_key`, 
send the `value` to the [`recorder`](@key) corresponding to the 
`recorder_key`. Otherwise, do nothing.
"""
function record_if_requested!(recorders, recorder_key::Symbol, value)
    if haskey(recorders.contents, recorder_key)
        record!(recorders.contents[recorder_key], recorders.shared, value)
    end
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
        recorders_contents.(locals(replicas)), 
        entangler(replicas)) 


function merge_recorders!(recorders_contents_1, recorders_contents_2)
    shared_keys = keys(recorders_contents_1)
    @assert shared_keys == keys(recorders_contents_2)

    values1 = values(recorders_contents_1)
    values2 = values(recorders_contents_2)
    merged_values = [combine!(values1[i], values2[i]) for i in eachindex(values1)]
    return (; zip(shared_keys, merged_values)...)
end