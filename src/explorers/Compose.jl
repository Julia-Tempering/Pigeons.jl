"""
A deterministic composition of two explorers. 
E.g. `Compose(SliceSampler(), AutoMALA())`
"""
@auto struct Compose 
    first 
    second 
end

adapt_explorer(explorer::Compose, reduced_recorders, current_pt, new_tempering) = 
    Compose(
        adapt_explorer(explorer.first, reduced_recorders, current_pt, new_tempering),
        adapt_explorer(explorer.second, reduced_recorders, current_pt, new_tempering)
    )

function step!(explorer::Compose, replica, shared)  
    step!(explorer.first, replica, shared) 
    step!(explorer.second, replica, shared)
end

function explorer_recorder_builders(explorer::Compose) 
    result = Function[] 
    append!(result, explorer_recorder_builders(explorer.first))
    append!(result, explorer_recorder_builders(explorer.second))
    return result
end
