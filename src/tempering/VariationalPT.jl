""" 
Parallel tempering with a variational reference described in 
[Surjanovic et al., 2022](https://arxiv.org/abs/2206.00080).
Note that this implements the stabilized version that includes
both a variational and a fixed reference distribution.
"""
struct VariationalPT
    """ The variational leg of stabilized PT. """
    variational_leg::NonReversiblePT

    """ The fixed leg of stabilized PT. """
    fixed_leg::NonReversiblePT
end

""" 
$SIGNATURES 

Parallel tempering with a variational reference described in 
[Surjanovic et al., 2022](https://arxiv.org/abs/2206.00080).
"""
function NonReversiblePT(inputs::Inputs)
    n_chains = number_of_chains(inputs)
    path = create_path(inputs.target, inputs)
    initial_schedule = equally_spaced_schedule(n_chains)
    return NonReversiblePT(path, initial_schedule, nothing)
end

function NonReversiblePT(path, schedule, communication_barriers)
    log_potentials = discretize(path, schedule)
    swap_graphs = deo(n_chains(schedule))
    return NonReversiblePT(path, schedule, log_potentials, swap_graphs, communication_barriers)
end

function adapt_tempering(tempering::NonReversiblePT, reduced_recorders, iterators, var_reference)
    update_path_if_needed!(tempering.path, reduced_recorders, iterators, var_reference)
    NonReversiblePT(
        tempering.path, 
        optimal_schedule(reduced_recorders, tempering.schedule), 
        communication_barriers(reduced_recorders, tempering.schedule)
    )
end

tempering_recorder_builders(::NonReversiblePT) = [swap_acceptance_pr, log_sum_ratio]