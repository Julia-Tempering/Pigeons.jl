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
    $TYPEDSIGNATURES

    If the [`recorders`](@ref) contains the given `recorder_key`, 
    send the `value` to the [`recorder`](@key) corresponding to the 
    `recorder_key`. Otherwise, do nothing.
    """
    function record_if_requested!(recorders, recorder_key::Symbol, value)
        if haskey(recorders, recorder_key)
            record!(recorders[recorder_key], value)
        end
    end
end

"""
$(TYPEDSIGNATURES)

Create a [`recorders`](@ref) from an [`Inputs`](@ref) and [`Shared`](@ref).
"""
@provides recorders create_recorders(inputs::Inputs, shared::Shared) =
    create_recorders(recorder_builders(inputs, shared)) 

"""
$(TYPEDSIGNATURES)

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
    recorders = (; zip(tuple_keys, tuple_values)...)
    return recorders
end

"""
A function such that calling it returns a fresh 
[`recorder`](@ref).
"""
@informal recorder_builder begin end

function recorder_builders(inputs::Inputs, shared::Shared)
    result = Set{Function}()
    union!(result, explorer_recorder_builders(shared.explorer))
    union!(result, tempering_recorder_builders(shared.tempering))
    union!(result, inputs.recorder_builders)
    return result
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