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
    """
    is_reference(swap_graphs, chain::Int) = @abstract 

    """
    $SIGNATURES
    """
    is_target(swap_graphs, chain::Int) = @abstract
end


