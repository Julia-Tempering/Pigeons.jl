"""
Default statistics exchanged by a pair of chains in the process of proposing a swap:

$FIELDS

See [`swap_stat()`](@ref)
"""
struct SwapStat 
    log_ratio::Float64 
    uniform::Float64
end

"""
Informs [`swap!()`](@ref) of how to perform a swap between a given pair of chains.

This is done in two steps:

- Use [`swap_stat()`](@ref) to extract sufficient statistics needed to make a swap decision. 
- Given these statistics for the two chains, [`swap_decision()`](@ref) then perform the swap.

The rationale for breaking this down into two steps is that in a distributed swap context, [`swap!()`](@ref) will
take care of transmitting the sufficient statistics over the network if necessary.

The function [`record_swap_stats!()`](@ref) is used to record information about swapping, 
in particular mean swap acceptance probabilities.

A default implementation of all of `pair_swapper`'s methods is provided, 
where the [`pair_swapper`](@ref) is assumed to follow the [`log_potentials`](@ref) interface.
"""
@informal pair_swapper begin
    """
    $SIGNATURES
    
    By default, two sufficient statistics are computed and stored in the [`SwapStat`](@ref) struct:

    - The result of calling [`log_unnormalized_ratio()`](@ref) on [`pair_swapper`](@ref)
    - A uniform number to coordinate the swap decision.

    This can be extended by dispatching on other `pair_swapper` types, with the 
    constraint that the returned sufficient statistics should satisfy `isbitstype()`.
    """
    function swap_stat(pair_swapper, replica::Replica, partner_chain::Int) 
        log_potentials = pair_swapper
        my_chain = replica.chain
        log_ratio = log_unnormalized_ratio(log_potentials, partner_chain, my_chain, replica.state)
        return SwapStat(log_ratio, rand(replica.rng))
    end

    """
    $SIGNATURES

    Given a [`pair_swapper`](@ref), a [`recorders`](@ref), the provided chain indices, and 
    the sufficient statistics computed by [`swap_stat()`](@ref), record statistics. 

    To avoid accumulating twice the same statistic with (chain1, chain2) and 
    (chain2, chain2), [`swap!()`](@ref) only calls this for the pair with chain1 < chain2.

    """
    function record_swap_stats!(pair_swapper, recorders, chain1::Int, stat1, chain2::Int, stat2)
        acceptance_pr = swap_acceptance_probability(stat1, stat2)
        key1 = (chain1, chain2)
        key2 = (chain2, chain1)
        @record_if_requested!(recorders, :swap_acceptance_pr, (key1, acceptance_pr))
        @record_if_requested!(recorders, :log_sum_ratio, (key1, stat1.log_ratio))
        @record_if_requested!(recorders, :log_sum_ratio, (key2, stat2.log_ratio)) # compute both to estimate a sandwich
    end

    """
    $SIGNATURES

    Given a [`pair_swapper`](@ref), a [`recorders`](@ref), the provided chain indices, and 
    the sufficient statistics computed by [`swap_stat()`](@ref), make a swap decision.

    By default, this is done as follows:
    
    1. compute the standard swap acceptance probability `min(1, exp(stat1.log_ratio + stat2.log_ratio))`
    2. make sure the two chains share the same uniform by picking the uniform from the chain with the smallest chain index 
    3. swap if the shared uniform is smaller than the swap acceptance probability.

    """
    function swap_decision(pair_swapper, chain1::Int, stat1, chain2::Int, stat2)
        acceptance_pr = swap_acceptance_probability(stat1, stat2)
        uniform = chain1 < chain2 ? stat1.uniform : stat2.uniform
        return uniform < acceptance_pr
    end
end

swap_acceptance_probability(stat1::SwapStat, stat2::SwapStat) = min(1, exp(stat1.log_ratio + stat2.log_ratio))


"""
For testing/benchmarking purposes, a simple 
[`pair_swapper`](@ref) where all swaps have equal 
acceptance probability. 

Could also be used to warm-start swap connections 
during exploration phase by setting that 
constant probability to zero.  
"""
struct TestSwapper 
    constant_swap_accept_pr::Float64

    """
    $SIGNATURES
    """
    @provides pair_swapper TestSwapper(constant_swap_accept_pr) = new(constant_swap_accept_pr)
end

"""
$SIGNATURES

See [`TestSwapper`](@ref).
"""
swap_stat(swapper::TestSwapper, replica::Replica, partner_chain::Int)::Float64 = rand(replica.rng)

"""
$SIGNATURES

See [`TestSwapper`](@ref).
"""
function swap_decision(swapper::TestSwapper, chain1::Int, stat1::Float64, chain2::Int, stat2::Float64)::Bool 
    uniform = chain1 < chain2 ? stat1 : stat2
    return uniform < swapper.constant_swap_accept_pr
end

"""
$SIGNATURES

See [`TestSwapper`](@ref).
"""
record_swap_stats!(swapper::TestSwapper, recorder, chain1::Int, stat1, chain2::Int, stat2) = nothing


# toy target based on TestSwapper

function initialization(target::TestSwapper, ::AbstractRNG, ::Int) 
    return nothing 
end

default_explorer(::TestSwapper) = nothing 
    step!(::Nothing, replica, shared) = nothing

sample_iid!(::TestSwapper, replica, shared) = nothing

create_path(testSwapper::TestSwapper, ::Inputs) = testSwapper
    interpolate(testSwapper::TestSwapper, beta) = testSwapper

create_pair_swapper(tempering, target::TestSwapper) = target
create_pair_swapper(tempering::StabilizedPT, target::TestSwapper) = target