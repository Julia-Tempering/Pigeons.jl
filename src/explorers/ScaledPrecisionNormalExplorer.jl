"""
Toy [`explorer`](@ref) for toy paths where each [`log_potential`](@ref) supports 
i.i.d. sampling via `rand(rng, log_potential)`.
"""
struct ScaledPrecisionNormalExplorer end

"""
$SIGNATURES
"""
@provides explorer create_explorer(target::ScaledPrecisionNormalPath, inputs) = ScaledPrecisionNormalExplorer()
create_state_initializer(target::ScaledPrecisionNormalPath) = Ref(zeros(target.dim))
step!(explorer::ScaledPrecisionNormalExplorer, replica, shared) = regenerate!(explorer, replica, shared)
adapt_explorer(explorer::ScaledPrecisionNormalExplorer, _, _) = explorer 
explorer_recorder_builders(::ScaledPrecisionNormalExplorer) = [] 
function regenerate!(explorer::ScaledPrecisionNormalExplorer, replica, shared)
    log_potential = find_log_potential(replica, shared) 
    replica.state = rand(replica.rng, log_potential)
end