include("supporting/mpi_test_utils.jl")

import Pigeons: my_global_indices, LoadBalance, my_load,
                find_process, split_slice

function test_load_balance(n_processes, n_tasks)
    for p in 1:n_processes
        lb = LoadBalance(p, n_processes, n_tasks)
        globals = my_global_indices(lb)
        @test length(globals) == my_load(lb)
        for g in globals
            @test find_process(lb, g) == p
        end
    end
end

@testset "LoadBalance" begin
    for i in 1:20
        for j in i:30
            test_load_balance(i, j)
        end
    end
end

@testset "Entanglement" begin
    mpi_test(1, joinpath(@__DIR__, "supporting/entanglement_test.jl"))
    mpi_test(2, joinpath(@__DIR__, "supporting/entanglement_test.jl"))

    mpi_test(1, joinpath(@__DIR__, "supporting/reduce_test.jl"))
    mpi_test(2, joinpath(@__DIR__, "supporting/reduce_test.jl"))
    mpi_test(3, joinpath(@__DIR__, "supporting/reduce_test.jl"))
end

@testset "PermutedDistributedArray" begin
    mpi_test(1, joinpath(@__DIR__, "supporting/permuted_test.jl"), options = ["-s"])
    mpi_test(1, joinpath(@__DIR__, "supporting/permuted_test.jl"))
    mpi_test(2, joinpath(@__DIR__, "supporting/permuted_test.jl"))
end

@testset "MPI backend" begin
    @info "MPI: using $(MPIPreferences.abi) ($(MPIPreferences.binary))"
    if haskey(ENV,"JULIA_MPI_TEST_BINARY")
        @test ENV["JULIA_MPI_TEST_BINARY"] == MPIPreferences.binary
    end
    if haskey(ENV,"JULIA_MPI_TEST_ABI")
        @test ENV["JULIA_MPI_TEST_ABI"] == MPIPreferences.abi
    end
end

@testset "Setup mpi" begin
    if haskey(ENV,"JULIA_MPI_TEST_BINARY") && ENV["JULIA_MPI_TEST_BINARY"] == "systemq"
        Pigeons.setup_mpi(; submission_system = :pbs)
        @test Pigeonsis_mpi_setup() == true
    end
end

@testset "GC+multithreading" begin
    mpi_test(2, joinpath(@__DIR__, "supporting/gc_test.jl"))
end