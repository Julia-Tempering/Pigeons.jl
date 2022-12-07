mutable struct Replica{S, T}
    state::S
    chain::Int             # Terminology (as in JRSSB NRPT paper): chain=i means we are currently using beta_i for that replica 
    rng::SplittableRandom
    recorder::T            # Records statistics. Each replica carries its own for thread safety/distribution, to reduced to access.
end

# useful for broadcasting, i.e.: chain.(replica)
chain(r::Replica) = r.chain 
state(r::Replica) = r.state
recorder(r::Replica) = r.recorder