@testset "src-sortable" begin
    cd("..") do
        Pigeons.sort_includes("Pigeons.jl")
    end
end