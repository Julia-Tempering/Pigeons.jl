using Pigeons
using Test
using Distributions
using Random
using SplittableRandoms


function test_load_balance(n_processes, n_tasks)
    for p in 1:n_processes
        lb = Pigeons.LoadBalance(p, n_processes, n_tasks)        
        globals = my_global_indices(lb)
        @assert length(globals) == my_load(lb)
        for g in globals
            @assert find_process(lb, g) == p
        end
    end
end

@testset "Entanglement" begin
    mpi_test(1, "entanglement_test.jl")
    mpi_test(2, "entanglement_test.jl")

    mpi_test(1, "reduce_test.jl")
    mpi_test(2, "reduce_test.jl")
    mpi_test(3, "reduce_test.jl")
end

@testset "recorder.jl" begin
    mpi_test(1, "recorder_test.jl")
    mpi_test(2, "recorder_test.jl")
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

@testset "test_swap" begin
    mpi_test(3, "swap_test.jl")
end

@testset "split_test" begin
    test_split_slice()
end


include("acceptance.jl")
include("adaptation.jl")
include("deo.jl")
include("exploration.jl")
include("restarts.jl")
include("NRPT.jl")
include("utils.jl")
include("summary.jl")
