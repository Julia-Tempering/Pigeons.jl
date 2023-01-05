@informal explorer begin
    regenerate!(explorer, replica, shared) = @abstract
    step!(explorer, replica, shared) = @abstract 
    adapt(explorer, reduced_recorders, shared) = @abstract
    recorder_builders(explorer) = @abstract 
end

find_log_potential(replica, shared) = shared.tempering.log_potentials[replica.chain]

@provides explorer create_explorer(inputs::Inputs) = create_explorer(inputs.inference_problem) 

create_explorer(inference_problem::ScaledPrecisionNormalPath) = ToyExplorer()

struct ToyExplorer end

step!(explorer::ToyExplorer, replica, shared) = regenerate!(explorer, replica, shared)
adapt!(::ToyExplorer, _, _) = nothing 
recorder_builders(::ToyExplorer) = [] 
function regenerate!(explorer::ToyExplorer, replica, shared)
    log_potential = find_log_potential(replica, shared) 
    replica.state = rand(replica.rng, log_potential)
end