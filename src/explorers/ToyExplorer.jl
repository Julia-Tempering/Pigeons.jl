"""
Toy [`explorer`](@ref) for toy paths where each [`log_potential`](@ref) supports 
i.i.d. sampling via `rand(rng, log_potential)`.
"""
struct ToyExplorer end

step!(explorer::ToyExplorer, replica, shared) = 
    replica.state = rand(
        replica.rng, 
        find_log_potential(replica, shared) )

adapt_explorer(explorer::ToyExplorer, _, _) = explorer 

explorer_recorder_builders(::ToyExplorer) = [] 

