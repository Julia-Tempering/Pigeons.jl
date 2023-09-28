include("supporting/setup.jl")


# check we are testing the checked-out version of the repo, not e.g. latest released version
test_dir = @__DIR__ 
@assert basename(test_dir) == "test"
project_root_dir = dirname(test_dir)
@assert pathof(Pigeons) == joinpath(project_root_dir, "src", "Pigeons.jl") 

@testset "issue 141" begin
    result = pigeons(
        target = toy_mvn_target(100), 
        checkpoint = true, 
        on = ChildProcess(n_local_mpi_processes = 4)
    )
end
