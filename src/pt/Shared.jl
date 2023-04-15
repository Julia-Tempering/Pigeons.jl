"""
Information shared by all processes involved in 
a round of distributed parallel tempering. 
This is updated between rounds but only read during 
a round. 

Fields:
$FIELDS

Only one instance maintained per process. 
"""
@concrete struct Shared
    """
    See [`Iterators`](@ref).
    """
    iterators

    """
    See [`tempering`](@ref).
    """
    tempering

    """
    See [`explorer`](@ref).
    """
    explorer

    """
    See [`var_reference`](@ref)
    """
    var_reference

    """ 
    See [`pair_swapper`](@ref)
    """
    swapper
end

"""
$SIGNATURES 

Create a [`Shared`](@ref) struct based on an [`Inputs`](@ref). 

Uses [`create_tempering()`](@ref) and [`create_explorer()`](@ref).
"""
function Shared(inputs)
    iterators = Iterators() 
    tempering = create_tempering(inputs)
    explorer = create_explorer(inputs) 
    var_reference = create_var_reference(inputs)
    swapper = create_pair_swapper(inputs, tempering.log_potentials)
    return Shared(iterators, tempering, explorer, var_reference, swapper)
end

