"""
The probability distribution of interest. 
"""
@informal target begin

    """
    $SIGNATURES

    Return a [`state_initializer`](@ref) used to populate 
    the states at the beginning of the first round of 
    Parallel Tempering. 
    """
    create_state_initializer(target, inputs::Inputs) = @abstract 

    """
    $SIGNATURES 

    Create an [`explorer`](@ref) for the given [`target`](@ref).
    """
    create_explorer(target, inputs::Inputs) = @abstract

    """
    $SIGNATURES 

    Create a default reference distribution, by returning a 
    [`log_potential`](@ref). The returned object will also get 
    passed to [`sample_iid!()`](@ref) at the "hot chains" of 
    the Parallel Tempering algorithm. 
    """
    create_reference_log_potential(target, inputs::Inputs) = @abstract

    """
    $SIGNATURES 

    Perform i.i.d. sampling on the given [`Replica`](@ref) 
    during its visit to the reference_log_potential created 
    by [`create_reference_log_potential()`](@ref).
    """
    sample_iid!(reference_log_potential, replica, shared) = @abstract

    """ 
    $SIGNATURES

    Create a [`path`](@ref), by default linking the given [`target`](@ref) to 
    the refence provided by [`create_reference_log_potential()`](@ref).

    For this default to work, the target should conform both 
    [`target`](@ref) and [`log_potential`](@ref).
    """ 
    create_path(target, inputs::Inputs) =  
        InterpolatingPath(
            create_reference_log_potential(target, inputs), 
            target)
end

sample_iid!(reference_log_potential::InterpolatedLogPotential, replica, shared) = 
    if reference_log_potential.beta == 0.0
        sample_iid!(reference_log_potential.path.ref, replica, shared) 
    else
        error()
    end