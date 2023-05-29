include("supporting/mpi_test_utils.jl")

@testset "Longer MPI" begin
    n_mpis = set_n_mpis_to_one_on_windows(4)
    recorder_builders = []
    pigeons(
        target = Pigeons.TestSwapper(0.5),
        n_rounds = 14,
        checked_round = 12,
        n_chains = 200,
        multithreaded = false,
        recorder_builders = recorder_builders,
        checkpoint = true,
        on = ChildProcess(
                n_local_mpi_processes = n_mpis,
                n_threads = 2,
                mpiexec_args = extra_mpi_args()))
end