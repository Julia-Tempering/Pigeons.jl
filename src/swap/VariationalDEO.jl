struct VariationalDEO
    n_chains_fixed::Int
    n_chains_var::Int
end

n_chains(deo::VariationalDEO) = deo.n_chains_fixed + deo.n_chains_var

"""
$SIGNATURES
Implements the Deterministic Even Odd (DEO) scheme but with two references 
(one fixed and one variational) as in [Surjanovic et al., 2022](https://arxiv.org/abs/2206.00080).
"""
@provides swap_graphs function variational_deo(n_chains_fixed, n_chains_var) 
    return VariationalDEO(n_chains_fixed, n_chains_var)
end

create_swap_graph(deo::VariationalDEO, shared) = 
    iseven(shared.iterators.scan) ? even(deo.n_chains_fixed, deo.n_chains_var) : odd(deo.n_chains_fixed, deo.n_chains_var)

is_reference(deo::VariationalDEO, chain::Int) = (chain == 1) || (chain == n_chains(deo))
is_target(deo::VariationalDEO, chain::Int) = (chain == deo.n_chains_var) || (chain == deo.n_chains_var + 1)