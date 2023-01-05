@informal temperer begin
    adapt(temperer, reduced_recorders) = @abstract
    create_tempering(temperer) = @abstract 
    recorder_builders(temperer) = @abstract 
end

@concrete struct Tempering
    log_potentials 
    swap_graphs 
end

n_chains(tempering::Tempering) = n_chains(tempering.log_potentials)

create_temperer(inputs) = jrssb_2021_temperer()

initial_n_chains(inputs) = inputs.min_n_chains

@concrete struct JRSSB_2021_Temperer
    path 
    schedule 
end

@provides temperer function jrssb_2021_temperer()
    n_chains = initial_n_chains(inputs)
    path = create_path(input.inference_problem, inputs)
    initial_schedule = Schedule(n_chains)
    return JRSSB_2021_Temperer(path, initial_schedule)
end

create_path(inference_problem::ScaledPrecisionNormalPath) = inference_problem

function adapt(temperer::JRSSB_2021_Temperer, reduced_recorders)
    path = temperer.path 
    barriers = communicationbarrier(reduced_recorders, temperer.schedule)
    updated_schedule = Schedule(
        n_chains(temperer.schedule), 
        barriers.cumulativebarrier)
    return JRSSB_2021(path, updated_schedule)
end

function tempering(temperer::JRSSB_2021_Temperer)
    log_potentials = discretize(temperer.path, temperer.schedule)
    swap_graphs = deo()
    return Tempering(log_potentials, swap_graphs)
end

recorder_builders(::JRSSB_2021_Temperer) = [swap_acceptance_pr]