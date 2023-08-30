"""
Information shared by all processes involved in 
a round of distributed parallel tempering. 
This is updated between rounds but only read during 
a round. 

Fields:
$FIELDS

Only one instance maintained per process. 
"""
@auto struct Shared
    """
    See [`Iterators`](@ref).
    """
    iterators::Iterators

    """
    See [`tempering`](@ref).
    """
    tempering

    """
    See [`explorer`](@ref).
    """
    explorer

    """
    Named tuple of DataFrame's
    """
    reports
end

Base.show(io::IO, s::Shared) = 
    print(io, "Shared($(s.iterators), $(s.tempering), $(s.explorer), ...)")


"""
$SIGNATURES 
Create a [`Shared`](@ref) struct based on an [`Inputs`](@ref). 
Uses [`create_tempering()`](@ref) and [`create_explorer()`](@ref).
"""
function Shared(inputs)
    iterators = Iterators() 
    tempering = create_tempering(inputs)
    explorer = create_explorer(inputs) 
    return Shared(iterators, tempering, explorer, init_dfs())
end

