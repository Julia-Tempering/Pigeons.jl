"""
Informs [`swap!()`](@ref) about which chain will interact with which.

These are instantiated by [`swap_graphs`](@ref). 

Canonical example is the standard Odd and Even swap. Extension point for e.g. 

- parallel parallel tempering,
- variational methods with more than 2 legs,
- PT algorithms dealing with more than one target simultaneously for the purpose of model selection. 
"""
@informal swap_graph begin
    """
    $SIGNATURES
    For a given [`swap_graph`](@ref) and input `chain` index, what chain will it interact with at the current iteration?
    Convention: if a chain is not interacting, return its index.
    """
    partner_chain(swap_graph, chain::Int) = @abstract

    """
    $SIGNATURES
    For a given [`swap_graph`](@ref) and input `chain` index, is the current chain a reference distribution?
    """
    is_reference(swap_graph, chain::Int) = @abstract 
    
    """
    $SIGNATURES
    For a given [`swap_graph`](@ref) and input `chain` index, is the current chain a target distribution?
    """
    is_target(swap_graph, chain::Int) = @abstract
end



