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
    initialize(target, rng::SplittableRandom, replica_index::Int) = @abstract 

    """
    $SIGNATURES 

    The default [`explorer`](@ref) for the given [`target`](@ref).
    """
    default_explorer(target) = SliceSampler() 

    """
    $SIGNATURES 

    Create a default reference distribution, by returning a 
    [`log_potential`](@ref). The returned object will also get 
    passed to [`sample_iid!()`](@ref) at the "hot chains" of 
    the Parallel Tempering algorithm. 
    """
    default_reference(target) = @abstract

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
            create_reference_log_potential(inputs), 
            target)
end

""" 
$SIGNATURES 

Given an [`Inputs`](@ref) object, either use `inputs.reference`, 
of if it is equal to `nothing` dispatch on 
`default_reference(inputs.target)` to construct the 
reference [`log_potential`](@ref) associated with the input target distribution.
"""
@provides log_potential create_reference_log_potential(inputs) = 
    if inputs.reference === nothing
        default_reference(inputs.target) 
    else
        inputs.reference 
    end


sample_iid!(reference_log_potential::InterpolatedLogPotential, replica, shared) = 
    if reference_log_potential.beta == 0.0
        sample_iid!(reference_log_potential.path.ref, replica, shared) 
    else
        error()
    end