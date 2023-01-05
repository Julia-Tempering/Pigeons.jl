@informal temperer begin
#    adapt(temperer, reduced_recorders) = @abstract
    create_tempering(temperer) = @abstract 
    recorder_builders(temperer) = @abstract 
end

@concrete struct Tempering
    log_potentials 
    swap_graphs 
end

n_chains(tempering::Tempering) = n_chains(tempering.log_potentials)
create_pair_swapper(tempering::Tempering, shared::Shared) = tempering.log_potentials

# Example: JRSSB (2021) scheme

create_temperer(inputs::Inputs) = jrssb_2021_temperer(inputs)

@concrete struct JRSSB_2021_Temperer
    path 
    schedule 
end

@provides temperer function jrssb_2021_temperer(inputs)
    n_chains = inputs.n_chains
    path = create_path(inputs.inference_problem, inputs)
    initial_schedule = equally_spaced_schedule(n_chains)
    return JRSSB_2021_Temperer(path, initial_schedule)
end

create_path(inference_problem::ScaledPrecisionNormalPath, inputs::Inputs) = inference_problem

function adapt(temperer::JRSSB_2021_Temperer, reduced_recorders)
    path = temperer.path 
    barriers = communicationbarrier(reduced_recorders, temperer.schedule)
    updated_schedule = adapted_schedule(
        n_chains(temperer.schedule), 
        barriers.cumulativebarrier)
    return JRSSB_2021(path, updated_schedule)
end

function create_tempering(temperer::JRSSB_2021_Temperer)
    log_potentials = discretize(temperer.path, temperer.schedule)
    swap_graphs = deo()
    return Tempering(log_potentials, swap_graphs)
end

recorder_builders(::JRSSB_2021_Temperer) = [swap_acceptance_pr]