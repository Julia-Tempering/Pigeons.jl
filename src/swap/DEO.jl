struct DEO 
    n_chains::Int
    reference_chains::Set{Int}
    target_chains::Set{Int}
end

"""
$SIGNATURES
Implements the Deterministic Even Odd (DEO) scheme proposed in [Okabe, 2001](https://www.sciencedirect.com/science/article/pii/S0009261401000550)
and analyzed in [Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464).
"""
@provides swap_graphs deo(n_chains) = DEO(n_chains, Set(1), Set(n_chains))

create_swap_graph(deo::DEO, shared) = iseven(shared.iterators.scan) ? even(deo.n_chains) : odd(deo.n_chains)
reference_chains(deo::DEO, shared) = deo.reference_chains
n_chains(deo::DEO, shared) = deo.n_chains
target_chains(deo::DEO, shared) = deo.target_chains