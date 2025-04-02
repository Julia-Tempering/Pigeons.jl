@testset "src-sortable" begin
    cd(dirname(dirname(pathof(Pigeons)))) do
        @test length(Pigeons.sort_includes("Pigeons.jl")) > 1
    end
end