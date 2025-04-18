# usage: julia test/benchmark.jl > test_results.csv

using Pkg
script_dir = @__DIR__
Pkg.activate(script_dir)
parent_dir = dirname(script_dir)
Pkg.develop(PackageSpec(path=parent_dir))

println("test_name,time_s,memory_B")

benchmark(timing, test_name::String) = println("$test_name,$(timing.time),$(timing.bytes)")

function benchmark(lambda::Function, test_name::String)
    benchmark(@timed(lambda()), test_name)
    benchmark(@timed(lambda()), test_name * " (second call)")
end

include_timing = @timed using Pigeons 
benchmark(include_timing, "using Pigeons")

benchmark("mvn-1000") do 
    pigeons(target = toy_mvn_target(1000), show_report = false)
end
