"""
    @record_if_requested!(recorders, recorder_key, value) 

Same behaviour as [`record_if_requested!`](@ref) but only evaluate 
`value` when the recorder is present. 
"""
macro record_if_requested!(recorders, recorder_key, value)
    return quote
        if !isnothing($(esc(recorders))) && haskey($(esc(recorders)), $(esc(recorder_key)))
            record!($(esc(recorders))[$(esc(recorder_key))], $(esc(value)))
        end
    end
end