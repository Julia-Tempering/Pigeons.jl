"""
One of the ``N`` components that forms the state maintained by a PT algorithm. A Replica ontains:
$(FIELDS)
"""
mutable struct Replica{S, T}
    """ Configuration in the state space. """
    state::S

    """ The index of the distribution currently associated with this replica, modified during swaps. """
    chain::Int  

    """ Random operations involving this state should use only this random number generator. """        
    rng::SplittableRandom

    """Records statistics. Each replica carries its own for thread safety/distribution, to be reduced to access."""
    recorder::T       
end

# useful for broadcasting, e.g., chain.(replica)
chain(r::Replica) = r.chain 
state(r::Replica) = r.state
recorder(r::Replica) = r.recorder