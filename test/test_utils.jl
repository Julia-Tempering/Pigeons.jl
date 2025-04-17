@testset "Test is_default_env" begin
    @test !Pigeons.is_default_env()
    original_project = Base.active_project()
    try
        Pkg.activate() # Activate default
        @show Base.active_project()
        @test Pigeons.is_default_env()
    finally
        Pkg.activate(original_project) 
    end
end