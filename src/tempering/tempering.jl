"""
Orchestrate the [`communicate!()`](@ref) phase 
of Parallel Tempering. 

In addition to the methods in the contract below, 
we also assume the presence of the following fields:
- [`log_potentials`](@ref)
- [`swap_graphs`](@ref)
- [`communication_barriers`](@ref)
- `path`
"""
@informal tempering begin
    """
    $SIGNATURES

    Called between successive rounds ([`run_one_round!`](@ref)). 

    Given a [`tempering`](@ref) and reduced [`recorders`](@ref) 
    return an updated [`tempering`](@ref).
    """
    adapt_tempering(tempering, reduced_recorders, iterators, variational, state) = @abstract
    
    """
    $SIGNATURES 

    What information is needed to perform [`adapt_tempering`](@ref)?
    Answer this by specifying an iterator containing [`recorder_builder`](@ref)'s. 
    Return `[]` if none are needed.
    """
    tempering_recorder_builders(tempering) = @abstract 

    """ 
    $SIGNATURES 

    Given a [`tempering`](@ref) and a [`target`](@ref), 
    create a [`pair_swapper`](@ref). 

    If omitted, by default will return the standard Metropolis-Hastings 
    accept-reject. 
    """
    create_pair_swapper(tempering, target) = tempering.log_potentials

    """
    $SIGNATURES 
    Find the [`log_potential`](@ref) for the chain 
    the replica is at, based on the [`tempering`](@ref) and [`Shared`](@ref) objects.  
    """
    find_log_potential(replica, tempering, shared) = @abstract
end

"""
$SIGNATURES

The global communication barrier. 
If the PT algorithm has both a fixed and variational 
references, return the barrier to the fixed one.
"""
global_barrier(pt) = global_barrier(pt.shared.tempering)

"""
$SIGNATURES 

Build the [`tempering`](@ref) needed for [`communicate!()`](@ref). 
"""
@provides tempering function create_tempering(inputs::Inputs) 
    if (n_chains_fixed(inputs) == 0) || (n_chains_var(inputs) == 0)
        return NonReversiblePT(inputs)
    else
        return StabilizedPT(inputs)
    end
end
