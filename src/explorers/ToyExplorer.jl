"""
Toy [`explorer`](@ref) for toy paths where each [`log_potential`](@ref) supports 
i.i.d. sampling via `rand!(rng, x, log_potential)`.
"""
struct ToyExplorer end

step!(::ToyExplorer, replica, shared) = 
    rand!(
        replica.rng, 
        replica.state, 
        find_log_potential(replica, shared)
    )

explorer_recorder_builders(::ToyExplorer) = [] 

