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
    swap_graphs = deo(number_of_chains(inputs))
    return VariationalPT(fixed_leg, variational_leg, swap_graphs)
end

function adapt_tempering(tempering::VariationalPT, reduced_recorders, iterators, var_reference)
    fixed_leg = adapt_tempering(tempering.fixed_leg, reduced_recorders, iterators, NoVarReference())
    variational_leg = adapt_tempering(tempering.variational_leg, reduced_recorders, iterators, var_reference)
    return VariationalPT(fixed_leg, variational_leg, tempering.swap_graphs)
end

tempering_recorder_builders(::VariationalPT) = [swap_acceptance_pr, log_sum_ratio]

create_pair_swapper(tempering::VariationalPT, target) = get_log_potentials(tempering)

function get_log_potentials(tempering::VariationalPT)
    return vcat(tempering.fixed_leg.log_potentials, tempering.variational_leg.log_potentials)
end