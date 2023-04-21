include("comrade-interface.jl")

r = pigeons(
        target = comrade_target, 
        n_rounds = 5, 
        n_chains = 10, 
        on = MPI(
            n_mpi_processes = 2, 
            dependencies = ["comrade-interface.jl"]))

# use watch(r) to see the output

watch(r)