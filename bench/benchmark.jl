# usage: julia test/benchmark.jl > test_results.csv

using Pkg
bench_dir = @__DIR__
Pkg.activate(bench_dir)
parent_dir = dirname(bench_dir)
Pkg.develop(PackageSpec(path=parent_dir))

include("setup.jl")

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
