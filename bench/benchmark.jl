include("activate_bench_env.jl")

println("test_name,time_s,memory_B,restarts,miness")
println("metainfo,Time<br>[s],Memory<br>[B],Restarts<br>,minESS<br>")
println("metainfo,lower,lower,higher,higher")

benchmark(time, mem, nrestart, miness, test_name::String) = println("$test_name,$time,$mem,$nrestart,$miness")

dry_run = false 
dry_run = true; println("Warning: performing dry run!") # uncomment to do quick dry run

function benchmark(lambda::Function, test_name::String)
	# collect result for first run including compilation
	first_result = @timed lambda()
	benchmark(first_result.time, first_result.bytes, Pigeons.n_tempered_restarts(first_result.value), minimum(ess(Chains(first_result.value)).nt.ess), test_name)

	# collect median time across 10 trials of precompiled run
	times = []
	mems = []
	restarts = []
	minesses = []
	for i=1:(dry_run ? 2 : 10)
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

# settings building blocks
n_rounds = 10 
n_chains = 10 # do not set higher than # cpus since we do MPI experiments
effort = dry_run ? (; n_rounds = 2, n_chains = 2) : (; n_rounds, n_chains)
base_settings = (; show_report = false, record = [traces; round_trip; record_default()], effort...)

# targets 
stan_8schools = load_target(PosteriorDBTargets, "eight_schools-eight_schools_centered") 
more_stan_targets = [
	"stan_lotka" => "hudson_lynx_hare-lotka_volterra", 
	"stan_gp"    => "gp_pois_regr-gp_regr", 
	"stan_garch" => "garch-garch11"
]

# first, a basic suite of quick native targets 
for targetId in find_targetIds(PigeonsExamples)
	target = load_target(PigeonsExamples, targetId)
	benchmark(string(targetId)) do 
		pigeons(; target, base_settings...) 
	end
	benchmark("$targetId-multithread") do 
		Pigeons.load(pigeons(; 
			target, 
			checkpoint = true, 
			multithreaded = true, 
			on = ChildProcess(
				n_threads = dry_run ? 2 : n_chains,
				dependencies = [PigeonsExamples]),
			base_settings...))
	end
end

# # compare single thread Stan vs. 10 local Stan MPI processes
benchmark("stan_8schools") do 
	pigeons(; target = stan_8schools, base_settings...) 
end
benchmark("stan_8schools-mpi") do 
	Pigeons.load(pigeons(; 
		target = stan_8schools, 
		checkpoint = true, 
		on = ChildProcess(
			n_local_mpi_processes = dry_run ? 2 : n_chains, 
			dependencies = [BridgeStan]), 
		base_settings...))
end

# a few more interesting Stan targets
for (short_name, targetId) in collect(more_stan_targets)
	target = load_target(PosteriorDBTargets, targetId)
	benchmark(short_name) do 
		pigeons(; target, base_settings...) 
	end
end

# Turing targets (slice sampling by default since there can be continuous and discrete)
for targetId in find_targetIds(TuringPigeonsExamples)
	if targetId != :galaxy # TODO: galaxy example leads to a bug with MCMChains
		target = load_target(TuringPigeonsExamples, targetId)
		benchmark("$targetId-slice") do 
			pt = pigeons(; target, base_settings...) 
			@assert pt.shared.explorer isa Pigeons.SliceSampler
			return pt
		end
	end
end

# TODO: Turing with AutoMALA and various AD back-ends (currently crashing)

# # Blang targets (TODO: needs Java 11)
# for targetId in find_targetIds(BlangTargets)
# 	target = load_target(BlangTargets, targetId)
# 	benchmark("$targetId") do 
# 		pigeons(; target, base_settings...) 
# 	end
# end
