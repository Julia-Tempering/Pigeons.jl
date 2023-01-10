"""
Specification of a local exploration kernel. 
"""
@informal explorer begin
    """
    $TYPEDSIGNATURES 

    Perform i.i.d. sampling on the given [`replica`](@ref). 
    This is only called when the replica is visiting a 
    reference chain. 

    The input [`explorer`](@ref) and [`Shared`](@ref) should only 
    be read, not written to. 

    See also [`find_log_potential`](@ref). 
    """
    regenerate!(explorer, replica, shared) = @abstract

    """
    $TYPEDSIGNATURES 

    Perform a transition on the given [`replica`](@ref) 
    invariant with respect to the distribution of the 
    replica's chain. 

    The input [`explorer`](@ref) and [`Shared`](@ref) should only 
    be read, not written to. 

    See also [`find_log_potential`](@ref). 
    """
    step!(explorer, replica, shared) = @abstract 

    adapt_explorer(explorer, reduced_recorders, shared) = @abstract
    explorer_recorder_builders(explorer) = @abstract 
end

"""
$TYPEDSIGNATURES 

Find the [`log_potential`](@ref) for the chain 
the replica is at, based on the [`Shared`](@ref) object.  
"""
find_log_potential(replica, shared) = shared.tempering.log_potentials[replica.chain]

""" 
$TYPEDSIGNATURES 

Given an [`Inputs`](@ref) object, dispatch on 
`create_explorer(inputs.target, inputs)` to construct the 
explorer associated with the input target distribution.
"""
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