"""
Informs [`swap!()`](@ref) about which chain will interact with which.

These are instantiated by [`swap_graphs`](@ref). 

Canonical example is the standard Odd and Even swap, extension point for e.g. 

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

    """
    $TYPEDSIGNATURES
    Given a [`swap_graph`](@ref), return the set of chain(s) targetting the distribution of interest. 
    """
    reference_chains(swap_graph) = @abstract 

    """
    $TYPEDSIGNATURES
    Given a [`swap_graph`](@ref), return the set of chain(s) targetting the reference distribution.
    These are typically tractable in the sense that we can sample 
    i.i.d. from them. 
    """
    target_chains(swap_graph) = @abstract
end

struct OddEven
    even::Bool
    n_chains::Int
end
odd(n_chains::Int) =  OddEven(false, n_chains)
even(n_chains::Int) = OddEven(true, n_chains)

"""
$TYPEDSIGNATURES
Implements the Deterministic Even Odd (DEO) scheme proposed in [Okabe, 2001](https://www.sciencedirect.com/science/article/pii/S0009261401000550)
and analyzed in [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
"""
@provides swap_graph deo(n_chains::Int, current_iteration::Int) = iseven(current_iteration) ? even(n_chains) : odd(n_chains)

function partner_chain(swap_graph::OddEven, chain::Int)
    @assert 1 ≤ chain ≤ swap_graph.n_chains
    direction = (iseven(chain) == swap_graph.even ? 1 : -1)
    proposed = chain + direction
    if      proposed == 0                       return 1
    elseif  proposed == swap_graph.n_chains + 1 return swap_graph.n_chains
    else                                        return proposed
    end
end

reference_chains(swap_graph::OddEven) = Set(1)

target_chains(swap_graph::OddEven) = Set(swap_graph.n_chains)