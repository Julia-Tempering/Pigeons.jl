"""
Creates one [`swap_graph`](@ref) for each communication 
iteration.
"""
@informal swap_graphs begin
    """
    $SIGNATURES

    Given a [`swap_graphs`](@ref) and [`Shared`](@ref), return 
    the [`swap_graph`](@ref) for the current iteration. 
    """
    create_swap_graph(swap_graphs, shared) = @abstract

    """
    $SIGNATURES

    Given a [`swap_graphs`](@ref) and [`Shared`](@ref), return 
    a `Set{Int}` of chain(s) indices targetting the distribution of interest. 
    """
    reference_chains(swap_graphs, shared) = @abstract 

    """
    $SIGNATURES

    Given a [`swap_graphs`](@ref) and [`Shared`](@ref), return the set of chain(s) targetting the reference distribution.
    These are typically tractable in the sense that we can sample 
    i.i.d. from them. 
    """
    target_chains(swap_graphs, shared) = @abstract
end


