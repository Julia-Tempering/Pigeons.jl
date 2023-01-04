"""
Information shared by all MPI processes involved in 
a round of distributed parallel tempering. 

Only one instance maintained per MPI process. 
"""
@concrete struct Shared
    inputs
    iterators
    tempering
    explorer
end

function Shared(inputs)
    iterators = Iterators() 
    tempering = create_tempering(inputs)
    explorer = create_explorer(inputs, tempering) 
    return Shared(inputs, iterators, tempering, explorer)
end



# TODO: at least as many as MPI processes..

# TODO: org better. maybe adapt.jl ?


