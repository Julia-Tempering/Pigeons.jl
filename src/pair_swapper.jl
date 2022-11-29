"""
pair_swapper: an informal interface, implementations take care of performing a swap between two parallel tempering chains.

A pair_swapper first extracts sufficient statistics needed to perform a swap (potentially to be transmitted over network).
    In the typical case, this will be log densities before and after proposed swap (or just the likelihood with linear 
    annealing paths), and a uniform [0, 1] variate.

Then based on two sets of sufficient statistics, deterministically decide if we should swap. 
"""
swap_stat(pair_swapper, replica::Replica, partner_chain::Int) = @abstract
swap_decision(pair_swapper, chain1::Int, stat1, chain2::Int, stat2)::Bool = @abstract

"""
pair_swapper for general path models. 
"""
struct Swapper{LP, R}
    log_potentials::Vector{LP}
    recorder::Recorder{R}
end
struct SwapStat
    current_log_potential::Float64
    translocated_log_potential::Float64 # what would be the log potential of current state if moved to the other chain (annealing parameter)?
    uniform::Float64
end
function swap_stat(swapper::Swapper, replica::Replica, partner_chain::Int) 
    my_chain = replica.chain
    current_log_potential      = swapper.log_potentials[my_chain](replica.state)
    translocated_log_potential = swapper.log_potentials[partner_chain](replica.state)
    return SwapStat(current_log_potential, translocated_log_potential, rand(replica.rng))
end
function swap_decision(swapper::Swapper, chain1::Int, stat1, chain2::Int, stat2)
    acceptance_pr = swap_acceptance_probability(stat1, stat2)
    uniform = chain1 < chain2 ? stat1.uniform : stat2.uniform
    if chain1 < chain2
        record_swap_stats!(swapper.recorder, chain1::Int, stat1, chain2::Int, stat2)
    end
    return uniform < acceptance_pr
end
swap_acceptance_probability(stat1::SwapStat, stat2::SwapStat) = 
    stat1.translocated_log_potential + stat2.translocated_log_potential -
   (stat1.current_log_potential      + stat2.current_log_potential)

"""
For testing/benchmarking purpose, a simple swap model where all swaps have equal acceptance probability. 
"""
struct TestSwapper 
    constant_swap_accept_pr::Float64
end
swap_stat(swapper::TestSwapper, replica::Replica, partner_chain::Int)::Float64 = rand(replica.rng)
function swap_decision(swapper::TestSwapper, chain1::Int, stat1::Float64, chain2::Int, stat2::Float64)::Bool 
    uniform = chain1 < chain2 ? stat1 : stat2
    return uniform < swapper.constant_swap_accept_pr
end