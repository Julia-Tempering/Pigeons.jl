""" 
Parallel tempering with a variational reference described in 
[Surjanovic et al., 2022](https://arxiv.org/abs/2206.00080).
This is an implementation of the *stabilized* version that includes
*both* a variational and a fixed reference distribution.
"""
struct VariationalPT
    """ 
    The fixed leg of stabilized PT. 
    Contains a [`path`](@ref), [`Schedule`](@ref), [`log_potentials`](@ref), 
    and [`communication_barriers`](@ref).
    [`swap_graphs`](@ref) is also included but is overwritten by this struct's [`swap_graphs`](@ref).
    """
    fixed_leg::NonReversiblePT
    
    """ The variational leg of stabilized PT. """
    variational_leg::NonReversiblePT
    
    """ The [`swap_graphs`](@ref). """
    swap_graphs
end


""" 
$SIGNATURES 

Parallel tempering with a variational reference described in 
[Surjanovic et al., 2022](https://arxiv.org/abs/2206.00080).
"""
function VariationalPT(inputs::Inputs)
    n_chains_fixed = number_of_chains_fixed(inputs)
    path_fixed = create_path(inputs.target, inputs)
    initial_schedule_fixed = equally_spaced_schedule(n_chains_fixed)
    fixed_leg = NonReversiblePT(path_fixed, initial_schedule_fixed, nothing)
    path_var = create_path(inputs.target, inputs) # start with the fixed reference
    n_chains_var = number_of_chains_var(inputs)
    initial_schedule_var = equally_spaced_schedule(n_chains_var)
    variational_leg = NonReversiblePT(path_var, initial_schedule_var, nothing)
    swap_graphs = variational_deo(n_chains_fixed, n_chains_var)
    return VariationalPT(fixed_leg, variational_leg, swap_graphs)
end

function adapt_tempering(tempering::VariationalPT, reduced_recorders, iterators, var_reference)
    fixed_leg = adapt_tempering(tempering.fixed_leg, reduced_recorders, iterators, NoVarReference())
    variational_leg = adapt_tempering(tempering.variational_leg, reduced_recorders, iterators, var_reference)
    return VariationalPT(fixed_leg, variational_leg, tempering.swap_graphs)
end

tempering_recorder_builders(::VariationalPT) = [swap_acceptance_pr, log_sum_ratio]

create_pair_swapper(tempering::VariationalPT, target) = 
    vcat(tempering.fixed_leg.log_potentials, reverse(tempering.variational_leg.log_potentials))
    # TODO: Update this to avoid unnecesary allocations

function find_log_potential(replica, tempering::VariationalPT, shared)
    tup = shared.indexer.i2t[replica.chain]
    if tup.leg == :fixed 
        return tempering.fixed_leg.log_potentials[tup.chain]
    elseif tup.leg == :variational 
        return tempering.variational_leg.log_potentials[tup.chain]
    end
end

"""
$SIGNATURES
Create an `Indexer` for stabilized variational PT. 
Given a chain number, return a tuple indicating the relative chain number 
within a leg of PT and the leg in which it is located. 
Given a tuple, return the global chain number.
"""
function create_replica_indexer(tempering::VariationalPT)
    n_chains_fixed = number_of_chains(tempering.fixed_leg)
    n_chains_var = number_of_chains(tempering.variational_leg)
    n_chains = n_chains_fixed + n_chains_var
    i2t = Vector{Any}(undef, n_chains)
    for i in 1:n_chains
        # reference ----- target -- target ---- reference 
        #     1     -----   N    -- N + 1  ----    2N
        if i ≤ n_chains_fixed 
            i2t[i] = (chain = i, leg = :fixed)
        else 
            i2t[i] = (chain = n_chains_var - (i - n_chains_fixed) + 1, leg = :variational)
        end
    end
    return Indexer(i2t)
end

global_barrier(tempering::VariationalPT) = 
    (
        tempering.fixed_leg.communication_barriers.globalbarrier, 
        tempering.variational_leg.communication_barriers.globalbarrier
    )