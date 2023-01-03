"""
Information shared by all machines. 
"""
@concrete struct Shared
    inputs::Inputs
    iterators::Iterators
    n_chains::Int
    state_initializer
end



