"""
Orchestrate the [`explore!()`](@ref) phase 
of Parallel Tempering. This is the part of the algorithm 
where each replica performs MCMC moves targeting its annealed 
distribution. 
"""
@informal explorer begin
    """
    $SIGNATURES 

    Perform a transition on the given [`Replica`](@ref) 
    invariant with respect to the distribution of the 
    replica's chain. 

    The input [`explorer`](@ref) and [`Shared`](@ref) should only 
    be read, not written to. 

    See also [`find_log_potential`](@ref). 
    """
    step!(explorer, replica, shared) = @abstract 

    """
    $SIGNATURES

    Called between successive rounds ([`run_one_round!`](@ref)). 

    By default, return the explorer without further adaptation.
    """
    adapt_explorer(explorer, reduced_recorders, current_pt, new_tempering) = explorer
    
    """ 
    $SIGNATURES

    What information is needed to perform [`adapt_explorer`](@ref)?
    Answer this by specifying an iterator containing [`recorder_builder`](@ref)'s. 
    Return `[]` if none are needed (default behaviour). 
    """
    explorer_recorder_builders(explorer) = []
end

""" 
$SIGNATURES 

Given an [`Inputs`](@ref) object, either use `inputs.explorer`, 
of if it is equal to `nothing` dispatch on 
`default_explorer(inputs.target)` to construct the 
explorer associated with the input target distribution.
"""
create_explorer(inputs) = 
    if inputs.explorer === nothing
        default_explorer(inputs.target) 
    else
        inputs.explorer 
    end
