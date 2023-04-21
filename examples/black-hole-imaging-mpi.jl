include("comrade-interface.jl")

r = pigeons(
        target = comrade_target_example(), 
        n_rounds = 10, 
        n_chains = 100, 
        on = MPI(
            n_mpi_processes = 100, 
            dependencies = ["comrade-interface.jl"]))

# use watch(r) to see the output

watch(r)