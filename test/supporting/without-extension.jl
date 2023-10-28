using Pkg

supporting_dir = @__DIR__
test_dir = dirname(supporting_dir)
@assert basename(test_dir) == "test"
project_root_dir = dirname(test_dir) # <- pigeons dir
Pkg.activate("$test_dir/supporting/env-pigeons-only")
Pkg.develop(PackageSpec(path=project_root_dir))

using Test 
@test_throws "UndefVarError: `toy_mvn_target` not defined" pigeons(target = toy_mvn_target(1))

using Pigeons
pigeons(target = toy_mvn_target(1))

@test_throws "MethodError: no method matching toy_stan_target(::Int64)" pigeons(target = toy_stan_target(2))

@test_throws "MethodError: no method matching toy_turing_target(::Int64)" pigeons(target = Pigeons.toy_turing_target(2))