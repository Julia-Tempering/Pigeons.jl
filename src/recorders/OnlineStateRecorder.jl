"""
Online statistics on the states.
"""
@kwdef struct OnlineStateRecorder
    stats::Dict{Pair{Symbol, Type}, Any} = Dict{Pair{Symbol, Type}, Any}()
end

"""
$SIGNATURES 

Compute the mean of the given variable from the output, the latter is either 
a [`PT`](@ref) or an [`OnlineStateRecorder`](@ref)
"""
mean(output, variable_name::Symbol) = get_statistic(output, variable_name, Mean) 

"""
$SIGNATURES 

Same as [`mean()`](@ref) but for the variance. 
"""
variance(output, variable_name::Symbol) = get_statistic(output, variable_name, Variance) 

get_statistic(pt::PT, variable_name::Symbol, t::Type{T}) where {T} = get_statistic(pt.reduced_recorders.target_online, variable_name, t)
function get_statistic(recorder::OnlineStateRecorder, variable_name::Symbol, ::Type{T}) where {T}
    key = Pair(variable_name, T)
    v = value(recorder.stats[key]) 
    return value.(v)
end  

Base.empty!(recorder::OnlineStateRecorder) = empty!(recorder.stats)

function Base.merge(recorder1::OnlineStateRecorder, recorder2::OnlineStateRecorder)
    if isempty(recorder1.stats)
        return recorder2 
    end
    if isempty(recorder2.stats)
        return recorder1 
    end
    current_keys = keys(recorder1.stats)
    @assert current_keys == keys(recorder2.stats) 
    result = OnlineStateRecorder()
    for key in current_keys
        result.stats[key] = merge(recorder1.stats[key], recorder2.stats[key])
    end
    return result 
end

""" 
$SIGNATURES 

The names (each a `Symbol`) of the continuous variables in the given state. 
"""
continuous_variables(state) = @abstract 

"""
$SIGNATURES 

The storage of the variable of the given name, typically an `Array`.
"""
variable(state, name::Symbol) = @abstract 

"""
$SIGNATURES
"""
continuous_variables(pt::PT) = continuous_variables(locals(pt.replicas)[1].state) 

const STATS = [Mean, Variance]
const SINGLETON_VAR = [:singleton_variable]
continuous_variables(state::Array) = SINGLETON_VAR
variable(state::Array, name::Symbol) = 
    if name === :singleton_variable
        state 
    else
        error()
    end

function record!(recorder::OnlineStateRecorder, state)
    if isempty(recorder.stats)
        initialize_online_state_recorder!(recorder.stats, state)
    end 
    for name in continuous_variables(state) 
        for stat in STATS # NB: the more natural "for key in keys(recorder.stats)" leads to allocations in the inner loop
            key = Pair(name, stat)
            fit!(recorder.stats[key], variable(state, name))
        end
    end
end

initialize_online_state_recorder!(stats, state) = 
    for stat_type in STATS
        initialize_online_state_recorder!(stats, state, stat_type)
    end 

initialize_online_state_recorder!(stats, state, ::Type{T}) where {T} = 
    for name in continuous_variables(state)
        var = variable(state, name) 
        collection = [T() for i in eachindex(var)] 
        key = Pair(name, T)
        stats[key] = Group(collection) 
    end

