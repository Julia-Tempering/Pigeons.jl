"""
$SIGNATURES

Randomly alternate between different explorers. 
E.g. `Mix(SliceSampler(), AutoMALA())`
$FIELDS
"""
@auto struct Mix
    """
    A tuple consisting of exploration kernels
    """
    explorers
end
Mix(explorers...) = Mix(Tuple(explorers))

adapt_explorer(explorer::Mix, reduced_recorders, current_pt, new_tempering) = 
    Mix(
        Tuple(adapt_explorer(e, reduced_recorders, current_pt, new_tempering) for e in explorer.explorers)
    )

step!(explorer::Mix, replica, shared) = 
    step!(rand(replica.rng, explorer.explorers), replica, shared) 

function explorer_recorder_builders(explorer::Mix)
    result = Function[]
    for e in explorer.explorers
        append!(result, explorer_recorder_builders(e))
    end
    return result
end