"""
Orchestrate the [`explore!()`](@ref) phase 
of Parallel Tempering. 
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
    
    Given an [`explorer`](@ref), reduced [`recorders`](@ref) 
    and [`Shared`](@ref) return an updated [`explorer`](@ref).
    """
    adapt_explorer(explorer, reduced_recorders, shared) = @abstract
    
    """ 
    $SIGNATURES

    What information is needed to perform [`adapt_explorer`](@ref)?
    Answer this by specifying an iterator containing [`recorder_builder`](@ref)'s. 
    Return `[]` if none are needed. 
    """
    explorer_recorder_builders(explorer) = @abstract 
end

""" 
$SIGNATURES 

Given an [`Inputs`](@ref) object, dispatch on 
`create_explorer(inputs.target, inputs)` to construct the 
explorer associated with the input target distribution.
"""
@provides explorer create_explorer(inputs) = create_explorer(inputs.target, inputs) 
