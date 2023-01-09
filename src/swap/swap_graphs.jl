"""
Creates one [`swap_graph`](@ref) for each communication 
iteration.
"""
@informal swap_graphs begin
    """
    $TYPEDSIGNATURES
    """
    create_swap_graph(swap_graphs, shared) = @abstract

    """
    $TYPEDSIGNATURES
    Given a [`swap_graphs`](@ref), return the set of chain(s) targetting the distribution of interest. 
    """
    reference_chains(swap_graphs, shared) = @abstract 

    """
    $TYPEDSIGNATURES
    Given a [`swap_graphs`](@ref), return the set of chain(s) targetting the reference distribution.
    These are typically tractable in the sense that we can sample 
    i.i.d. from them. 
    """
    target_chains(swap_graphs, shared) = @abstract
end

struct DEO end

"""
$TYPEDSIGNATURES
Implements the Deterministic Even Odd (DEO) scheme proposed in [Okabe, 2001](https://www.sciencedirect.com/science/article/pii/S0009261401000550)
and analyzed in [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
"""
@provides swap_graphs deo() = DEO()

create_swap_graph(deo::DEO, shared) = iseven(shared.iterators.round) ? even(n_chains(deo, shared)) : odd(n_chains(deo, shared))
reference_chains(::DEO, shared) = Set(1)
n_chains(::DEO, shared) = n_chains(shared.tempering.schedule)
target_chains(deo::DEO, shared) = Set(n_chains(deo, shared))
