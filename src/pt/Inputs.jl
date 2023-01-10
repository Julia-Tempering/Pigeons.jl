"""
Used to create Parallel Tempering algorithms. 

Fields:
$FIELDS
"""
@kwdef mutable struct Inputs{I}
    """ The target distribution. """
    target::I

    """ The master random seed. """
    seed::Int = 1

    """ The number of rounds to run. """
    n_rounds::Int = 10

    """ The number of chains to use. """
    n_chains::Int = 10

    """ 
    Whether a checkpoint should be written to disk 
    at the end of each round. 
    """
    checkpoint::Bool = true

    """
    An Vector with elements of type 
    [`recorder_builder`](@ref). 
    """
    recorder_builders::Vector = Function[]

    """
    The round index where [`run_checks()`](@ref) will 
    be performed. Set to 0 to skip these checks. 
    """
    checked_round::Int = 0
end

