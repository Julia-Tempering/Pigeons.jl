import Pigeons: TreeReference, directed_max_tree
using DataStructures

dummy = 999

## Generate a complete graph with 5 vertices
function generate_test_tree()
    dim = 5
    adjacency_list = Dict{Int, Vector{Tuple{Float64, Float64, Int, Int}}}()

    for i = 1:dim
        adjacency_list[i] = Vector{Tuple{Float64, Float64, Int, Int}}()
    end

    append!(adjacency_list[1], [(1, dummy, 1,2), (2, dummy, 1,3), (3, dummy, 1,4), (4, dummy, 1,5)])
    append!(adjacency_list[2], [(1, dummy, 2,1), (5, dummy, 2,3), (8, dummy, 2,4), (6, dummy, 2,5)])
    append!(adjacency_list[3], [(2, dummy, 3,1), (5, dummy, 3,2), (7, dummy, 3,4), (9, dummy, 3,5)])
    append!(adjacency_list[4], [(3, dummy, 4,1), (8, dummy, 4,2), (7, dummy, 4,3), (10, dummy, 4,5)])
    append!(adjacency_list[5], [(4, dummy, 5,1), (6, dummy, 5,2), (9, dummy, 5,3), (10, dummy, 5,4)])

    return adjacency_list
end

@testset "Spanning tree maximality" begin
    root = 1
    tree = directed_max_tree(generate_test_tree(), root)

    @test length(tree) == 4
    
    expected = [(4, dummy, 1,5), (10, dummy, 5, 4), (8, dummy, 4, 2), (9, dummy, 5, 3)]
    for edge in expected
        @test edge in expected
    end
end