"""
Mid-level API to specify which chain will interact with which.

Given chain at input index, what index will it swap with?
Convention: if a chain is not interacting, return its index.

Canonical example is the standard Odd and Even swap implemented below.

Extension point for e.g. implementing variational methods with more than 2 legs,
    or PT algorithms dealing with more than one target simultaneously for 
    the purpose of model selection. 
"""
partner_chain(swap_graph, index::Int) = @abstract

struct OddEven
    even::Bool
    n_chains::Int
end
odd(n_chains::Int) =  OddEven(false, n_chains)
even(n_chains::Int) = OddEven(true, n_chains)
deo(n_chains::Int, current_iteration::Int) = iseven(current_iteration) ? even(n_chains) : odd(n_chains)
function partner_chain(swap_graph::OddEven, index::Int)
    @assert 1 ≤ index ≤ swap_graph.n_chains
    direction = (iseven(index) == swap_graph.even ? 1 : -1)
    proposed = index + direction
    if      proposed == 0                       return 1
    elseif  proposed == swap_graph.n_chains + 1 return swap_graph.n_chains
    else                                        return proposed
    end
end