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
end

Base.show(io::IO, nrpt::NonReversiblePT) = 
    print(io, "NonReversiblePT($(nrpt.path), $(nrpt.schedule))")

""" 
$SIGNATURES 

The adaptive non-reversible Parallel Tempering described in 
[Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464). 
"""
function NonReversiblePT(inputs::Inputs)
    n_chains = inputs.n_chains
    path = create_path(inputs.target, inputs)
    initial_schedule = equally_spaced_schedule(n_chains)
    return NonReversiblePT(path, initial_schedule)
end

function NonReversiblePT(path, schedule)
    log_potentials = discretize(path, schedule)
    swap_graphs = deo(n_chains(schedule))
    return NonReversiblePT(path, schedule, log_potentials, swap_graphs)
end

adapt_tempering(tempering::NonReversiblePT, reduced_recorders) =
    NonReversiblePT(
        tempering.path, 
        optimal_schedule(
            reduced_recorders, 
            tempering.schedule
        )
    )

tempering_recorder_builders(::NonReversiblePT) = [swap_acceptance_pr, log_sum_ratio]