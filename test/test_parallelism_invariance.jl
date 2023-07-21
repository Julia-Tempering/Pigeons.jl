using DynamicPPL

include("supporting/turing_models.jl")
include("supporting/mpi_test_utils.jl")

@testset "Parallelism Invariance" begin
    n_mpis = set_n_mpis_to_one_on_windows(4)
    record = [swap_acceptance_pr, index_process, log_sum_ratio, round_trip, energy_ac1]

    # various explorers on a Julia function and on a Stan model
    for explorer in [SliceSampler(), AutoMALA(), Compose(SliceSampler(), AutoMALA())]
        for target in [toy_mvn_target(1), toy_stan_target(1)]
            pigeons(;
                target, 
                n_rounds = 10,
                explorer, 
                checked_round = 3, 
                record,
                checkpoint = true, 
                on = ChildProcess(
                        n_local_mpi_processes = n_mpis,
                        n_threads = 2,
                        mpiexec_args = extra_mpi_args())) 
        end
    end

    # Turing:
    for model in [flip_model_unidentifiable(), flip_mixture()]
        pigeons(
            target = TuringLogPotential(model), 
            n_rounds = 4,
            checked_round = 3, 
            multithreaded = true,
            record,
            checkpoint = true, 
            on = ChildProcess(
                    dependencies = [Distributions, DynamicPPL, LinearAlgebra, joinpath(@__DIR__, "supporting/turing_models.jl")],
                    n_local_mpi_processes = n_mpis,
                    n_threads = 2,
                    mpiexec_args = extra_mpi_args()))
    end

    # Blang:
    if !Sys.iswindows() # JNI crashes on windows; see commit right after c016f59c84645346692f720854b7531743c728bf
        Pigeons.setup_blang("blangDemos")
        pigeons(; 
            target = Pigeons.blang_ising(), 
            n_rounds = 10,
            checked_round = 3, 
            record, 
            multithreaded = true, 
            checkpoint = true, 
            on = ChildProcess(
                    n_local_mpi_processes = n_mpis,
                    n_threads = 2,
                    mpiexec_args = extra_mpi_args()))
    end
end