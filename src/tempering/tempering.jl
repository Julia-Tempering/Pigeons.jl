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
    adapt_tempering(tempering, reduced_recorders, iterators, var_reference) = @abstract
    
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

    get_log_potentials(tempering) = @abstract
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
