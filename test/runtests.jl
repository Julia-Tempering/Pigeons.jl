include("supporting/setup.jl")

# check we are testing the checkout version of the repo, not e.g. latest released version
test_dir = @__DIR__ 
@assert basename(test_dir) == "test"
project_root_dir = dirname(test_dir)
@assert pathof(Pigeons) == joinpath(project_root_dir, "src", "Pigeons.jl") 

# load all files starting with "test_"
for test_name in filter(x -> startswith(x, "test_") && endswith(x, ".jl"), readdir(test_dir)) 
             # + - yes, we need this horror, because we are dealing with a macro
             # v 
    @testset "$test_name" include(test_name)
end