"""
Orchestrate the [`communicate!()`](@ref) phase 
of Parallel Tempering. 

In addition to the methods in the contract below, 
we also assume the presence of the following fields:
- [`log_potentials`](@ref)
- [`swap_graphs`](@ref)
- [`communication_barriers`](@ref)
"""
@informal tempering begin
    """
    $SIGNATURES

    Called between successive rounds ([`run_one_round!`](@ref)). 

    Given a [`tempering`](@ref) and reduced [`recorders`](@ref) 
    return an updated [`tempering`](@ref).
    """
    adapt_tempering(tempering, reduced_recorders, iterators, var_reference, state) = @abstract
    
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
   
    """
    $SIGNATURES
    Find the global communication barrier for the given [`tempering`](@ref).
    May be a single value or a tuple (in the case of multiple references.)
    """
    global_barrier(tempering) = @abstract

    """
    $SIGNATURES
    Optional.
    Create an [`Indexer`](@ref) for the replicas in this `tempering` object.
    E.g. the replica indexer is used to determine to which leg a chain belongs 
    and its relative chain index for multi-leg PT methods.
    """
    create_replica_indexer(tempering) = nothing
end

"""
$SIGNATURES 

Build the [`tempering`](@ref) needed for [`communicate!()`](@ref). 
"""
@provides tempering function create_tempering(inputs::Inputs) 
    if (number_of_chains_fixed(inputs) == 0) | (number_of_chains_var(inputs) == 0)
        return NonReversiblePT(inputs)
    else
        return VariationalPT(inputs)
    end
end
