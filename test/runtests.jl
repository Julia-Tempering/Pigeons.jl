using Pigeons

using ArgMacros
using Distributions
using DynamicPPL
using LinearAlgebra
using MPI
using MPIPreferences
using OnlineStats
using Random
using Serialization
using SplittableRandoms
using Statistics
using Test

import Pigeons: my_global_indices, LoadBalance, my_load,
                find_process, split_slice

include("misc.jl")
include("slice_sampler_test.jl")
include("var_reference_test.jl")
include("turing.jl")
include("vector.jl")

function test_load_balance(n_processes, n_tasks)
    for p in 1:n_processes
        lb = LoadBalance(p, n_processes, n_tasks)        
        globals = my_global_indices(lb)
        @assert length(globals) == my_load(lb)
        for g in globals
            @assert find_process(lb, g) == p
        end
    end
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

@testset "GC+multithreading" begin
    mpi_test(2, "gc_test.jl")
end

@testset "Stepping stone" begin
    pt = pigeons(target = toy_mvn_target(100));
    p = stepping_stone_pair(pt)
    truth = Pigeons.analytic_lognormalization(toy_mvn_target(100))
    @test abs(p[1] - truth) < 1
    @test abs(p[2] - truth) < 1
end

@testset "Round trips" begin
    n_chains = 4
    n_rounds = 5
    
    pt = pigeons(; target = Pigeons.TestSwapper(1.0), recorder_builders = [Pigeons.round_trip], n_chains, n_rounds);
    
    len = 2^(n_rounds)
    truth = 0.0
    for i in 0:(n_chains-1)
        truth += floor(max(len - i, 0) / n_chains / 2)
    end

    @test truth == Pigeons.n_round_trips(pt)
end

@testset "Moments" begin
    pt = pigeons(target = toy_mvn_target(2), recorder_builders = [Pigeons.target_online], n_rounds = 20);
    for var_name in Pigeons.continuous_variables(pt)
        m = mean(pt, var_name)
        for i in eachindex(m)
            @test abs(m[i] - 0.0) < 0.001
        end
        v = var(pt, var_name) 
        for i in eachindex(v) 
            @test abs(v[i] - 0.1) < 0.001 
        end
    end
end



@testset "Parallelism Invariance" begin
    n_mpis = set_n_mpis_to_one_on_windows(4)
    recorder_builders = [swap_acceptance_pr, index_process, log_sum_ratio, round_trip, energy_ac1]

    # test swapper 
    pigeons(
        target = toy_mvn_target(1), 
        n_rounds = 10,
        checked_round = 3, 
        recorder_builders = recorder_builders,
        checkpoint = true, 
        on = ChildProcess(
                n_local_mpi_processes = n_mpis,
                n_threads = 2,
                mpiexec_args = extra_mpi_args())) 

    # Turing:
    pigeons(
        target = TuringLogPotential(flip_model_unidentifiable()), 
        n_rounds = 10,
        checked_round = 3, 
        multithreaded = true,
        recorder_builders = recorder_builders,
        checkpoint = true, 
        on = ChildProcess(
                dependencies = [Distributions, DynamicPPL, LinearAlgebra, "turing.jl"],
                n_local_mpi_processes = n_mpis,
                n_threads = 2,
                mpiexec_args = extra_mpi_args()))

    # Blang:
    if !Sys.iswindows() # JNI crashes on windows; see commit right after c016f59c84645346692f720854b7531743c728bf
        Pigeons.setup_blang("blangDemos")
        pigeons(; 
            target = Pigeons.blang_ising(), 
            n_rounds = 10,
            checked_round = 3, 
            recorder_builders = recorder_builders, 
            multithreaded = true, 
            checkpoint = true, 
            on = ChildProcess(
                    n_local_mpi_processes = n_mpis,
                    n_threads = 2,
                    mpiexec_args = extra_mpi_args()))
    end
end

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

@testset "Entanglement" begin
    mpi_test(1, "entanglement_test.jl")
    mpi_test(2, "entanglement_test.jl")

    mpi_test(1, "reduce_test.jl")
    mpi_test(2, "reduce_test.jl")
    mpi_test(3, "reduce_test.jl")
end

@testset "PermutedDistributedArray" begin
    mpi_test(1, "permuted_test.jl", options = ["-s"])
    mpi_test(1, "permuted_test.jl")
    mpi_test(2, "permuted_test.jl")
end

@testset "LoadBalance" begin
    for i in 1:20
        for j in i:30
            test_load_balance(i, j)
        end
    end
end

@testset "LogSum" begin
    m = Pigeons.LogSum()
    
    fit!(m, 2.1)
    fit!(m, 4)
    v1 = value(m)
    @assert v1 ≈ log(exp(2.1) + exp(4))


    fit!(m, 2.1)
    fit!(m, 4)
    m2 = Pigeons.LogSum() 
    fit!(m2, 50.1)
    combined = merge(m, m2)
    @assert value(combined) ≈ log(exp(v1) + exp(50.1))

    fit!(m, 2.1)
    fit!(m, 4)
    empty!(m)
    @assert value(m) == -Pigeons.inf(0.0)
end

function test_split_slice()
    # test disjoint random streams
    set = Set{Float64}()
    push!(set, test_split_slice_helper(1:10)...)
    push!(set, test_split_slice_helper(11:20)...)
    @test length(set) == 20

    # test overlapping
    set = Set{Float64}()
    push!(set, test_split_slice_helper(1:15)...)
    push!(set, test_split_slice_helper(10:20)...)
    @test length(set) == 20
    return true
end

test_split_slice_helper(range) = [rand(r) for r in split_slice(range,  SplittableRandom(1))]

@testset "split_test" begin
    test_split_slice()
end

@testset "Serialize" begin
    mpi_test(1, "serialization_test.jl")
end

@testset "SliceSampler" begin
    test_slice_sampler()
end

@testset "Variational reference" begin
    test_var_reference()
end
