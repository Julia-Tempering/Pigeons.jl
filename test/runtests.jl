include("supporting/setup.jl")

is_windows_in_CI() = Sys.iswindows() && (get(ENV, "CI", "false") == "true")

# check we are testing the checked-out version of the repo, not e.g. latest released version
test_dir = @__DIR__ 
@assert basename(test_dir) == "test"
project_root_dir = dirname(test_dir)
@assert pathof(Pigeons) == joinpath(project_root_dir, "src", "Pigeons.jl") 

# load all files starting with "test_"
for test_name in filter(x -> startswith(x, "test_") && endswith(x, ".jl"), readdir(test_dir)) 
    # organize output a little bit
    println() # v otherwise can't tell what is running when it crashes in the middle
    println("### Starting $test_name")
             # + - yes, we need this horror, because we are dealing with a macro
             # v 
    @testset "$test_name" include(test_name)
end