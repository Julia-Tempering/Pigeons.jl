using Pkg
bench_dir = @__DIR__
Pkg.activate(bench_dir)
parent_dir = dirname(bench_dir)
Pkg.develop(PackageSpec(path=parent_dir))

include("setup.jl")

function main()
    # load the two results dataframes
    results = DataFrame(CSV.File("bench/benchmark.csv"))
    results_new = DataFrame(CSV.File("bench/benchmark_new.csv"))
    
    # outer join (to account for new/removed tests)
    results_compared = outerjoin(results, results_new, on=:test_name, renamecols = "_old" => "_new")
    
    # compute the percentage change in time/mem
    results_compared.time_s_pct = round.(100 * (results_compared.time_s_new .- results_compared.time_s_old) ./ results_compared.time_s_old, digits=2)
    results_compared.memory_B_pct = round.(100 * (results_compared.memory_B_new .- results_compared.memory_B_old) ./ results_compared.memory_B_old, digits=2)
    
    # round old/new results to 2 significant figures
    results_compared.time_s_new = round.(results_compared.time_s_new, sigdigits=2)
    results_compared.time_s_old = round.(results_compared.time_s_old, sigdigits=2)
    results_compared.memory_B_new = round.(results_compared.memory_B_new, sigdigits=2)
    results_compared.memory_B_old = round.(results_compared.memory_B_old, sigdigits=2)
    
    # order the columns nicely
    results_compared = results_compared[:, ["test_name", "time_s_old", "time_s_new", "time_s_pct", "memory_B_old", "memory_B_new", "memory_B_pct"]]
    
    # nicer names for the columns
    new_names = Dict(:test_name => "Test", :time_s_new => "New Time<br>[s]", :time_s_old => "Old Time<br>[s]",
                     :memory_B_new => "New Memory<br>[B]", :memory_B_old => "Old Memory<br>[B]",
    		 :time_s_pct => "ΔTime<br>[%]", :memory_B_pct => "ΔMemory<br>[%]")
    rename!(results_compared, new_names)
    
    # output the markdown representation
    results_str = pretty_table(String, results_compared; backend=Val(:markdown))

    # remove datatypes and "nothing" at the end
    to_remove = ["nothing", "<br>`Float64`", "<br>`String31`", "<br>`Int64`"]
    for s in to_remove
    	results_str = replace(results_str, s => "")
    end
    
    # print the result
    println(results_str)
end

main()
