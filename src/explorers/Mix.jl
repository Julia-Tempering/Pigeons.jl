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
    """
    The base number of steps (equivalently, momentum refreshments) between swaps.
    This base number gets multiplied by `ceil(Int, dim^(exponent_n_refresh))`. 
    """
    categorical
end
function Mix(explorers::Tuple, probs::AbstractVector{<:Real})
    @assert length(explorers) == length(probs)
    Mix(explorers, Categorical(probs))
end
Mix(explorers::Tuple) = Mix(explorers, Categorical(length(explorers)))
Mix(explorers...; probs=fill(inv(length(explorers)),length(explorers))) = 
    Mix(Tuple(explorers),probs)
adapt_explorer(explorer::Mix, reduced_recorders, current_pt, new_tempering) = 
    Mix(
        Tuple(adapt_explorer(e, reduced_recorders, current_pt, new_tempering) for e in explorer.explorers),
        explorer.categorical
    )

step!(explorer::Mix, replica, shared) = 
    step!(explorer.explorers[rand(replica.rng, explorer.categorical)], replica, shared) 

function explorer_recorder_builders(explorer::Mix)
    result = Function[]
    for e in explorer.explorers
        append!(result, explorer_recorder_builders(e))
    end
    return result
end