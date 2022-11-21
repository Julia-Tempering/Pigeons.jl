using Pigeons
using Test
using Distributions
using Random
using SplittableRandoms


@testset "Pigeons.jl" begin
    # Write your tests here
end

@testset "NRPT fixed reference test: normal distribution" begin
    Random.seed!(2340981)
    N = 2
    initial_state = [[5.0] for _ in 1:(N+1)]
    ntotal = 200
    V_0(θ) = -logpdf(Normal(10.0, 1.0), θ[1])
    prior_sampler() = [rand(Normal(10.0, 1.0))]
    V_1(θ) = -logpdf(Normal(0.0, 1.0), θ[1])
    out = Pigeons.NRPT(V_0, V_1, initial_state, ntotal, N, optimreference = false, prior_sampler = prior_sampler).states
    final_states = map((i) -> out[i][end], 1:length(out))
    final_mean = mean(final_states)[1]
    @test (final_mean < 0.5) && (final_mean > -0.5)
end

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
    mpi_test(1, "test/entanglement_test.jl")
    mpi_test(2, "test/entanglement_test.jl")
end

@testset "PermutedDistributedArray" begin
    mpi_test(1, "test/permuted_test.jl", options = ["-s"])
    mpi_test(1, "test/permuted_test.jl")
    mpi_test(2, "test/permuted_test.jl")
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
    mpi_test(3, "test/swap_test.jl")
end

@testset "split_test" begin
    test_split_slice()
end


