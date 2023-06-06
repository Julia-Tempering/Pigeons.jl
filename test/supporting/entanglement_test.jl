using Pigeons
using OnlineStats
using Random

import Pigeons: Entangler, 
                my_global_indices, transmit,
                my_load


"""
Run from runtests.jl
"""

function test_entanglement()

    size = 21
    rng = MersenneTwister(1)
    serial = randperm(rng, size)

    e = Entangler(size)
    
    my_globals = my_global_indices(e.load)

    data = serial[my_globals]
    received = transmit(e, data, data)

    if e.load.my_process_index == 1
        @assert received == collect(1:my_load(e.load))
    end

end

test_entanglement()