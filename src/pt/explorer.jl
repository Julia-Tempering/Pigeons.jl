@informal explorer begin
    regenerate!(explorer, replica, shared) = @abstract
    step!(explorer, replica, shared) = @abstract 
    adapt_explorer(explorer, reduced_recorders, shared) = @abstract
    explorer_recorder_builders(explorer) = @abstract 
end

find_log_potential(replica, shared) = shared.tempering.log_potentials[replica.chain]

@provides explorer create_explorer(inputs) = create_explorer(inputs.target, inputs) 

# toy implementation for testing
struct ToyExplorer end

create_state_initializer(target::ScaledPrecisionNormalPath, inputs) = Ref(zeros(target.dim))

create_explorer(target::ScaledPrecisionNormalPath, inputs) = ToyExplorer()

step!(explorer::ToyExplorer, replica, shared) = regenerate!(explorer, replica, shared)
adapt_explorer(explorer::ToyExplorer, _, _) = explorer 
explorer_recorder_builders(::ToyExplorer) = [] 
function regenerate!(explorer::ToyExplorer, replica, shared)
    log_potential = find_log_potential(replica, shared) 
    replica.state = rand(replica.rng, log_potential)
end