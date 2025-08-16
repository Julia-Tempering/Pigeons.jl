# usage: julia test/benchmark.jl > test_results.csv

using Pkg
bench_dir = @__DIR__
Pkg.activate(bench_dir)
parent_dir = dirname(bench_dir)
Pkg.develop(PackageSpec(path=parent_dir))

include("setup.jl")

println("test_name,time_s,memory_B")

benchmark(time, mem, test_name::String) = println("$test_name,$time,$mem")

function benchmark(lambda::Function, test_name::String)
	# collect timing for first run including compilation
	first_timing = @timed lambda()
	benchmark(first_timing.time, first_timing.bytes, test_name)

	# collect median time across 10 trials of precompiled run
	times = []
	mems = []
	for i=1:10
		timing = @timed lambda()
		append!(times, timing.time)
		append!(mems, timing.bytes)
	end
	benchmark(median(times), median(mems), test_name * " (second call)")
end

using_time = @timed using Pigeons 
benchmark(using_time.time, using_time.mem, "using Pigeons")

benchmark("mvn-1000") do 
    pigeons(target = toy_mvn_target(1000), show_report = false)
end
