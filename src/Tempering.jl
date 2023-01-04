@concrete struct Tempering
    n_chains 
    log_potentials 
    pair_swapper 
    swap_graphs 
end

function create_tempering(inputs)
    n_chains = initial_n_chains(inputs)
    log_potentials = discretize(create_path(inputs), initial_schedule(inputs, n_chains))
    return Tempering(n_chains, log_potentials, log_potentials, deo())
end

initial_n_chains(inputs) = inputs.min_n_chains
