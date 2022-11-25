"""
pair_swapper: an informal interface, implementations take care of performing a swap between two parallel tempering chains.

A pair_swapper first extracts sufficient statistics needed to perform a swap (potentially to be transmitted over network).
    In the typical case, this will be log densities before and after proposed swap (or just the likelihood with linear 
    annealing paths), and a uniform [0, 1] variate.

Then based on two sets of sufficient statistics, deterministically decide if we should swap. 
"""

swapstat(pair_swapper, replica::Replica, partner_chain::Int) = @abstract

swap_decision(pair_swapper, chain1::Int, stat1, chain2::Int, stat2)::Bool = @abstract

