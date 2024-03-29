"""
One of the ``N`` components that forms the state maintained by a PT algorithm. A Replica contains:
$(FIELDS)
"""
mutable struct Replica{S, T}
    """ Configuration in the state space. """
    state::S

    """ 
    The index of the distribution currently associated 
    with this replica, modified during swaps. 
    """
    chain::Int  

    """ 
    Random operations involving this state should 
    use only this random number generator. 
    """        
    rng::SplittableRandom

    """
    Records statistics. Each replica carries its own 
    for thread safety/distribution; then they are 
    reduced at end of each round.
    """
    recorders::T   
    
    """A global id associated with this replica.""" 
    replica_index::Int 
end

# useful for broadcasting, e.g., chain.(replica)
chain(r::Replica) = r.chain 
_recorders(r::Replica) = r.recorders
