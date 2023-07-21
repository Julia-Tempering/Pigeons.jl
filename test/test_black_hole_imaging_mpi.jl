include("supporting/comrade-interface.jl")

@testset "Comrade MPI" begin
    r = pigeons(
            target = comrade_target_example(), 
            n_rounds = 2, 
            n_chains = 2, 
            checkpoint = true,
            record = record_online(),
            on = ChildProcess( # for actual MPI, use "MPI(" instead of "ChildProcess("
                n_local_mpi_processes = 2, # for actual MPI, use n_mpi_processes instead
                dependencies = ["$(@__DIR__)/supporting/comrade-interface.jl"]))

    # use this to see the output in a cluster envirnoment:
    # watch(r)

    # to load the full information in the memory of the local machine
    pt = load(r)
end