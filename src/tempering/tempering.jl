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
    adapt_tempering(tempering, reduced_recorders) = @abstract
    
    """
    $SIGNATURES 

    What information is needed to perform [`adapt_tempering`](@ref)?
    Answer this by specifying an iterator containing [`recorder_builder`](@ref)'s. 
    Return `[]` if none are needed.
    """
    tempering_recorder_builders(tempering) = @abstract 
end

""" 
$SIGNATURES 

By default will return the standard Metropolis-Hastings 
accept-reject. 
"""
create_pair_swapper(inputs, log_potentials) = inputs.fused_swaps ? 
    FusedSwap(log_potentials) :
    log_potentials

"""
$SIGNATURES 

Build the [`tempering`](@ref) need for [`communicate!()`](@ref). 
"""
@provides tempering create_tempering(inputs::Inputs) = NonReversiblePT(inputs)
