"""
Mid-level API to specify which chain will interact with which.

Given chain at input index, what index will it swap with at the current iteration?
Convention: if a chain is not interacting, return its index.

Canonical example is the standard Odd and Even swap implemented below.

Extension point for e.g. 
    - parallel parallel tempering
    - variational methods with more than 2 legs,
    - PT algorithms dealing with more than one target simultaneously for the purpose of model selection. 
"""
@informal swap_graph begin
    """
    $TYPEDSIGNATURES
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
deo(n_chains::Int, current_iteration::Int) = iseven(current_iteration) ? even(n_chains) : odd(n_chains)

"""$TYPEDSIGNATURES"""
function partner_chain(swap_graph::OddEven, chain::Int)
    @assert 1 ≤ chain ≤ swap_graph.n_chains
    direction = (iseven(chain) == swap_graph.even ? 1 : -1)
    proposed = chain + direction
    if      proposed == 0                       return 1
    elseif  proposed == swap_graph.n_chains + 1 return swap_graph.n_chains
    else                                        return proposed
    end
end

"""$TYPEDSIGNATURES"""
reference_chains(swap_graph::OddEven) = Set(1)

"""$TYPEDSIGNATURES"""
target_chains(swap_graph::OddEven) = Set(swap_graph.n_chains)