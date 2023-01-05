"""
Information shared by all MPI processes involved in 
a round of distributed parallel tempering. 

Only one instance maintained per MPI process. 
"""
@concrete struct Shared
    inputs
    iterators
    temperer
    explorer
end

function Shared(inputs)
    iterators = Iterators() 
    temperer = create_temperer(inputs)
    explorer = create_explorer(inputs) 
    return Shared(inputs, iterators, temperer, explorer)
end

