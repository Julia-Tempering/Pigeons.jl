""" 
Variables needed for the non-reversible Parallel Tempering described in 
[Syed et al., 2021](https://rss.onlinelibrary.wiley.com/doi/10.1111/rssb.12464):

$FIELDS
"""
@auto struct NonReversiblePT
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
    n = n_chains(inputs)
    path = create_path(inputs.target, inputs)
    initial_schedule = equally_spaced_schedule(n)
    return NonReversiblePT(path, initial_schedule, nothing)
end

function NonReversiblePT(path, schedule, communication_barriers)
    log_potentials = discretize(path, schedule)
    swap_graphs = deo(n_chains(schedule))
    return NonReversiblePT(path, schedule, log_potentials, swap_graphs, communication_barriers)
end

function adapt_tempering(tempering::NonReversiblePT, reduced_recorders, iterators, variational, state)  
    if length(tempering.schedule.grids) == 1
        return tempering
    end
    adapt_tempering(tempering, reduced_recorders, iterators, variational, state, 1:(n_chains(tempering)-1))
end

function adapt_tempering(tempering::NonReversiblePT, reduced_recorders, iterators, variational, state, chain_indices)
    new_path = update_path_if_needed(tempering.path, reduced_recorders, iterators, variational, state)
    return NonReversiblePT(
        new_path, 
        optimal_schedule(reduced_recorders, tempering.schedule, chain_indices), 
        communication_barriers(reduced_recorders, tempering.schedule, chain_indices)
    )
end

tempering_recorder_builders(::NonReversiblePT) = [
    swap_acceptance_pr,
    log_sum_ratio # technically not needed, but it's basically free and e.g. record = [traces] would mask it 
    ]
find_log_potential(replica, tempering::NonReversiblePT, shared) = tempering.log_potentials[replica.chain]
n_chains(tempering::NonReversiblePT) = n_chains(tempering.schedule)
global_barrier(tempering::NonReversiblePT) = tempering.communication_barriers.globalbarrier