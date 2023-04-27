abstract type AbstractOddEven end
""" Provides a [`swap_graph`](@ref). """
struct OddEven <: AbstractOddEven
    even::Bool
    n_chains::Int
end
odd(n_chains::Int) =  OddEven(false, n_chains)
even(n_chains::Int) = OddEven(true, n_chains)

n_chains(swap_graph::OddEven) = swap_graph.n_chains

is_reference(::OddEven, chain::Int) = chain == 1
is_target(deo::OddEven, chain::Int) = chain == deo.n_chains


""" Provides a [`swap_graph`](@ref). """
struct VariationalOddEven
    even::Bool
    n_chains_fixed::Int
    n_chains_var::Int
    n_chains::Int 
end

function partner_chain(swap_graph::Union{AbstractOddEven, VariationalOddEven}, chain::Int)
    @assert 1 ≤ chain ≤ swap_graph.n_chains
    direction = (iseven(chain) == swap_graph.even ? 1 : -1)
    proposed = chain + direction
    if      proposed == 0                       return 1
    elseif  proposed == swap_graph.n_chains + 1 return swap_graph.n_chains
    else                                        return proposed
    end
end

function VariationalOddEven(even::Bool, n_chains_fixed::Int, n_chains_var::Int)
    VariationalOddEven(even, n_chains_fixed, n_chains_var, n_chains_fixed + n_chains_var)
end

function odd(n_chains_fixed::Int, n_chains_var::Int) 
    VariationalOddEven(false, n_chains_fixed, n_chains_var)
end

function even(n_chains_fixed::Int, n_chains_var::Int) 
    VariationalOddEven(true, n_chains_fixed, n_chains_var)
end

n_chains(swap_graph::VariationalOddEven) = swap_graph.n_chains

is_reference(deo::VariationalOddEven, chain::Int) = (chain == 1) || (chain == n_chains(deo))
is_target(deo::VariationalOddEven, chain::Int) = (chain == deo.n_chains_fixed) || (chain == deo.n_chains_fixed + 1)
