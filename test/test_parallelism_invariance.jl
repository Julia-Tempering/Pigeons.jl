include("supporting/turing_models.jl")
include("supporting/mpi_test_utils.jl")

@testset "Parallelism Invariance" begin
    n_mpis = set_n_mpis_to_one_on_windows(2)
    record = [swap_acceptance_pr, index_process, log_sum_ratio, round_trip, energy_ac1]
    targets = Any[toy_mvn_target(1)]
    is_windows_in_CI() || push!(targets, toy_stan_target(1))
    results = String[] # stores exec folders for afterwards testing `compare_checkpoints`

    @testset "Julia+Stan targets * multiple explorers" begin
        # various explorers on a Julia function and on a Stan model
        # this should be basically the same as autoMALA with the default preconditioner
        mixed_AM = Mix(
            AutoMALA(preconditioner=Pigeons.IdentityPreconditioner(), base_n_refresh=1),
            AutoMALA(preconditioner=Pigeons.MixDiagonalPreconditioner(0,0), base_n_refresh=1), # turn off zero-one inflation
            AutoMALA(preconditioner=Pigeons.DiagonalPreconditioner(), base_n_refresh=1)
        )
        for explorer in [SliceSampler(), AutoMALA(), Compose(SliceSampler(), AutoMALA()), mixed_AM]
            for target in targets
                @show explorer, target
                @show is_stan = target isa Pigeons.StanLogPotential

                # setting to true puts too much pressure on CI instances? https://github.com/Julia-Tempering/Pigeons.jl/actions/runs/5627897144/job/15251121621?pr=90
                multithreaded = is_stan ? false : true

                r = pigeons(;
                    target,
                    n_rounds = 10,
                    n_chains = 4,
                    explorer,
                    checked_round = 3,
                    multithreaded,
                    record,
                    checkpoint = true,
                    on = ChildProcess(
                            n_local_mpi_processes = n_mpis,
                            n_threads = multithreaded ? 2 : 1,
                            mpiexec_args = extra_mpi_args(),
                            dependencies = [BridgeStan]
                            ))
                push!(results, r.exec_folder)
                @test true # lets us count the number of tests passed
            end
        end
    end

    @testset "Turing targets" begin
        for model in [flip_model_unidentifiable(), flip_mixture()]
            r = pigeons(;
                target = TuringLogPotential(model),
                n_rounds = 4,
                n_chains = 4,
                checked_round = 3,
                multithreaded = true,
                record,
                checkpoint = true,
                on = ChildProcess(
                        dependencies = [Distributions, DynamicPPL, LinearAlgebra, joinpath(@__DIR__, "supporting/turing_models.jl")],
                        n_local_mpi_processes = n_mpis,
                        n_threads = 2,
                        mpiexec_args = extra_mpi_args()))
            push!(results, r.exec_folder)
            @test true
        end
    end

    @testset "Blang targets" begin
        if !Sys.iswindows() # JNI crashes on windows; see commit right after c016f59c84645346692f720854b7531743c728bf
            Pigeons.setup_blang("blangDemos")
            r = pigeons(;
                target = Pigeons.blang_ising(),
                n_rounds = 10,
                n_chains = 4,
                checked_round = 3,
                record,
                multithreaded = true,
                checkpoint = true,
                on = ChildProcess(
                        n_local_mpi_processes = n_mpis,
                        n_threads = 2,
                        mpiexec_args = extra_mpi_args()))
            push!(results, r.exec_folder)
            @test true
        end
    end
    
    @testset "compare_checkpoints throws on distinct inputs" begin
        # test that `compare_checkpoints` errors on every pair of distinct results sets
        # note: need to deserialize immutables for both sets of (incompatible) results 
        for (a,b) in Iterators.product(results,results)
            if a != b
                empty!(Pigeons.immutables)
                merge!(Pigeons.immutables, deserialize(joinpath(a,"immutables.jls")))
                merge!(Pigeons.immutables, deserialize(joinpath(b,"immutables.jls")))
                @test_throws "detected non-reproducibility" Pigeons.compare_checkpoints(a, b, true)
            end
        end
    end
end
