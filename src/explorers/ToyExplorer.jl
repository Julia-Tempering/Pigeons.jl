"""
Toy [`explorer`](@ref) for toy paths where each [`log_potential`](@ref) supports 
i.i.d. sampling via `rand(rng, log_potential)`.
"""
struct ToyExplorer end

"""
$SIGNATURES 
"""
@provides explorer create_explorer(target::ScaledPrecisionNormalPath, inputs) = ToyExplorer()
create_state_initializer(target::ScaledPrecisionNormalPath) = Ref(zeros(target.dim))
step!(explorer::ToyExplorer, replica, shared) = sample_iid!(explorer, replica, shared)
adapt_explorer(explorer::ToyExplorer, _, _) = explorer 
explorer_recorder_builders(::ToyExplorer) = [] 
function sample_iid!(explorer::ToyExplorer, replica, shared)
    log_potential = find_log_potential(replica, shared) 
    replica.state = rand(replica.rng, log_potential)
end