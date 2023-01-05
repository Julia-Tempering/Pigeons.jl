"""
Informs [`swap!()`](@ref) about which chain will interact with which.

These are instantiated by [`swap_graphs`](@ref). 

Canonical example is the standard Odd and Even swap. Extension point for e.g. 

- parallel parallel tempering
- variational methods with more than 2 legs,
- PT algorithms dealing with more than one target simultaneously for the purpose of model selection. 
"""
@informal swap_graph begin
    """
    $TYPEDSIGNATURES
    For a given [`swap_graph`](@ref) and input `chain` index, what chain will it interact with at the current iteration?
    Convention: if a chain is not interacting, return its index.
    """
    partner_chain(swap_graph, chain::Int) = @abstract
end

struct OddEven
    even::Bool
    n_chains::Int
end
odd(n_chains::Int) =  OddEven(false, n_chains)
even(n_chains::Int) = OddEven(true, n_chains)

n_chains(swap_graph::OddEven) = swap_graph.n_chains
function partner_chain(swap_graph::OddEven, chain::Int)
    @assert 1 ≤ chain ≤ swap_graph.n_chains
    direction = (iseven(chain) == swap_graph.even ? 1 : -1)
    proposed = chain + direction
    if      proposed == 0                       return 1
    elseif  proposed == swap_graph.n_chains + 1 return swap_graph.n_chains
    else                                        return proposed
    end
end


