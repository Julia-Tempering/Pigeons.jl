"""
Information shared by all MPI processes involved in 
a round of distributed parallel tempering. 

Only one instance maintained per MPI process. 
"""
@concrete mutable struct Shared
    inputs
    iterators
    tempering
    explorer
end

function Shared(inputs)
    iterators = Iterators() 
    tempering = create_tempering(inputs)
    explorer = create_explorer(inputs) 
    return Shared(inputs, iterators, tempering, explorer)
end

