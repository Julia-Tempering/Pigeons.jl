"""
Creates one [`swap_graph`](@ref) for each communication 
iteration.
"""
@informal swap_graphs begin
    """
    $SIGNATURES
    """
    create_swap_graph(swap_graphs, shared) = @abstract

    """
    $SIGNATURES
    Given a [`swap_graphs`](@ref), return the set of chain(s) targetting the distribution of interest. 
    """
    reference_chains(swap_graphs, shared) = @abstract 

    """
    $SIGNATURES
    Given a [`swap_graphs`](@ref), return the set of chain(s) targetting the reference distribution.
    These are typically tractable in the sense that we can sample 
    i.i.d. from them. 
    """
    target_chains(swap_graphs, shared) = @abstract
end


