#=
- cd to the examples directory
- activate
- if in the process of developping Pigeons, make sure to call Pkg.develop("Pigeons") so 
    that the dep in Manifest point to the local file rather than the last published 
=#

include("comrade-interface.jl")

pt = pigeons(target = comrade_target_example(), n_rounds = 2);

nothing;