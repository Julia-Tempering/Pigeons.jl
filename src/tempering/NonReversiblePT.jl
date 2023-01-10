# Example: JRSSB (2021) scheme

@provides tempering create_tempering(inputs::Inputs) = NonReversiblePT(inputs)

@concrete struct NonReversiblePT
    path 
    schedule 
    log_potentials 
    swap_graphs
end

Base.show(io::IO, nrpt::NonReversiblePT) = 
    print(io, "NonReversiblePT($(nrpt.path), $(nrpt.schedule))")


@provides tempering function NonReversiblePT(path, schedule)
    log_potentials = discretize(path, schedule)
    swap_graphs = deo()
    return NonReversiblePT(path, schedule, log_potentials, swap_graphs)
end

@provides temperer function NonReversiblePT(inputs::Inputs)
    n_chains = inputs.n_chains
    path = create_path(inputs.target, inputs)
    initial_schedule = equally_spaced_schedule(n_chains)
    return NonReversiblePT(path, initial_schedule)
end


function adapt_tempering(tempering::NonReversiblePT, reduced_recorders)
    path = tempering.path 
    barriers = communicationbarrier(reduced_recorders, tempering.schedule)
    updated_schedule = adapted_schedule(
        n_chains(tempering.schedule), 
        barriers.cumulativebarrier)
    return NonReversiblePT(path, updated_schedule)
end

tempering_recorder_builders(::NonReversiblePT) = [swap_acceptance_pr]