mutable struct Replica{S}
    state::S
    chain::Int # Terminology (as in JRSSB NRPT paper): chain=i means we are currently using beta_i for that replica 
    rng::SplittableRandom
end
chain(r::Replica) = r.chain # useful for broadcasting with chain.(replica)
