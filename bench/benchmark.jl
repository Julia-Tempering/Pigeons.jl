using Pkg
bench_dir = @__DIR__
Pkg.activate(bench_dir)
parent_dir = dirname(bench_dir)
Pkg.develop(PackageSpec(path=parent_dir))

include("setup.jl")

println("test_name,time_s,memory_B,restarts,miness")
println("metainfo,Time<br>[s],Memory<br>[B],Restarts<br>,minESS<br>")
println("metainfo,lower,lower,higher,higher")

benchmark(time, mem, nrestart, miness, test_name::String) = println("$test_name,$time,$mem,$nrestart,$miness")

function benchmark(lambda::Function, test_name::String)
	# collect result for first run including compilation
	first_result = @timed lambda()
	benchmark(first_result.time, first_result.bytes, Pigeons.n_tempered_restarts(first_result.value), minimum(ess(Chains(first_result.value)).nt.ess), test_name)

	# collect median time across 10 trials of precompiled run
	times = []
	mems = []
	restarts = []
	minesses = []
	for i=1:10
		result = @timed lambda()
		append!(times, result.time)
		append!(mems, result.bytes)
		append!(restarts, Pigeons.n_tempered_restarts(result.value))
		append!(minesses, minimum(ess(Chains(result.value)).nt.ess))
	end
	benchmark(median(times), median(mems), median(restarts), median(minesses), test_name * " (second call)")
end

using_result = @timed using Pigeons 
benchmark(using_result.time, using_result.bytes, 0, 0, "using Pigeons")

benchmark("mvn-1000") do 
    pigeons(target = toy_mvn_target(1000), show_report = false, record = [traces; round_trip; record_default()])
end

