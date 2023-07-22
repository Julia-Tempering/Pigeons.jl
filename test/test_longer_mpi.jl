include("supporting/mpi_test_utils.jl")

@testset "Longer MPI" begin
    n_mpis = set_n_mpis_to_one_on_windows(4)
    pigeons(
        target = Pigeons.TestSwapper(0.5),
        n_rounds = 14,
        checked_round = 12,
        n_chains = 200,
        multithreaded = false,  # setting to true puts too much pressure on CI instances? https://github.com/Julia-Tempering/Pigeons.jl/actions/runs/5627897144/job/15251121621?pr=90
        record = [],
        checkpoint = true,
        on = ChildProcess(
                n_local_mpi_processes = n_mpis,
                n_threads = 2,
                mpiexec_args = extra_mpi_args()))
end