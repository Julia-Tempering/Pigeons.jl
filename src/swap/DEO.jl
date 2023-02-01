struct DEO 
    n_chains::Int
end

"""
$SIGNATURES
Implements the Deterministic Even Odd (DEO) scheme proposed in [Okabe, 2001](https://www.sciencedirect.com/science/article/pii/S0009261401000550)
and analyzed in [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
"""
@provides swap_graphs deo(n_chains) = DEO(n_chains)

create_swap_graph(deo::DEO, shared) = iseven(shared.iterators.scan) ? even(deo.n_chains) : odd(deo.n_chains)
is_reference(::DEO, chain::Int) = chain == 1
is_target(deo::DEO, chain::Int) = chain == deo.n_chains
n_chains(deo::DEO) = deo.n_chains
