abstract type VarReference end
"""
A variational reference distribution.
"""
@informal var_reference begin
    
    """
    $SIGNATURES
    Choose on which rounds/scans to activate the variational reference.
    """
    activate_var_reference(var_reference::VarReference, iterators) = iterators.round ≥ 6 ? true : false
    
    """
    $SIGNATURES
    Update the variational reference and the annealing path.
    """
    update_var_reference!(var_reference::VarReference, path) = @abstract

    """
    $SIGNATURES
    Specify the recorder builders for this variational reference family.
    """
    var_reference_recorder_builders(var_reference::VarReference) = @abstract
    
    """
    $SIGNATURES
    """
    sample_iid!(var_reference::VarReference) = @abstract
    
    
    
    # - will need to specify:
    # -- update/adapt function
    # -- special sampler
    # -- create_state_initializer???
    # -- create_explorer???
    
    # you need to define a special log_potential::VarReference type so that your sampler can dispatch on this type
    
    # what you want to do is change adapt_tempering on line 43 of NRPT.jl so that the path AND annealing schedule also
    # get updated. use the "reduced_recorders" object to do this.
end


@provides var_reference create_var_reference() = GaussianReference()


