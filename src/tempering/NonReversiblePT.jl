""" 
Variables needed for the non-reversible Parallel Tempering described in 
[Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464):

$FIELDS
"""
@concrete struct NonReversiblePT
    """ The [`path`](@ref). """
    path 

    """ The [`Schedule`](@ref). """
    schedule 

    """ The [`log_potentials`](@ref). """
    log_potentials 

    """ The [`swap_graphs`](@ref). """
    swap_graphs

    """ 
    The communication barriers computed by 
    [`communication_barriers()`](@ref) at the 
    same time as this tempering was created; or 
    nothing before adaptation, i.e. before the 
    first call to [`adapt_tempering`](@ref).
    """
    communication_barriers
end

Base.show(io::IO, nrpt::NonReversiblePT) = 
    print(io, "NonReversiblePT($(nrpt.path), $(nrpt.schedule))")

""" 
$SIGNATURES 

The adaptive non-reversible Parallel Tempering described in 
[Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464). 
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
get_log_potentials(tempering::NonReversiblePT) = tempering.log_potentials