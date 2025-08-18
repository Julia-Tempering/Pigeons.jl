using Pkg
bench_dir = @__DIR__
Pkg.activate(bench_dir)
parent_dir = dirname(bench_dir)
Pkg.develop(PackageSpec(path=parent_dir))

include("setup.jl")

function print_single(val, color)
    s = "\$\\color{$color}"
    s *= @sprintf "%.2g" val
    s *= "\$"
    return s
end

function print_diff(old, new; lower_better=true)
    s = "\$"
    if (lower_better && new <= old) || (!lower_better && old <= new)
        s *= "\\color{green}"
    else
        s *= "\\color{red}"
    end
    s *= @sprintf "%.2g" old
    s *= "\\to"
    s *= @sprintf "%.2g" new
    s *= "\$"
    return s
end
     
function main()
    # load the CSV files
    # first two data rows are metainfo: human-readable column titles, lower/higher better
    meta_csv = CSV.File("bench/benchmark.csv")
    meta_new_csv = CSV.File("bench/benchmark_new.csv")

    # every row after that are benchmarking data rows
    results = DataFrame(CSV.File("bench/benchmark.csv", skipto=4))
    results_new = DataFrame(CSV.File("bench/benchmark_new.csv", skipto=4))

    # get all column names across old and new results
    allnames = union(names(results), names(results_new))

    # outer join (to account for new/removed tests)
    results_compared = outerjoin(results, results_new, on=:test_name, renamecols = "_old" => "_new")

    results_clean = DataFrame()
    human_readable_names = Dict("test_name" => "Benchmark")
    for nm in allnames
        # if the column is for test names, just skip
        if nm == "test_name"
            results_clean[!,nm] = results_compared[!,nm]
        # if both old and new have this column
        elseif nm * "_old" in names(results_compared) && nm * "_new" in names(results_compared)
            lower = (meta_new_csv[nm][2] == "lower")
            results_clean[!,nm] = print_diff.(results_compared[!,nm*"_old"], results_compared[!,nm*"_new"], lower_better = lower)
            human_readable_names[nm] = meta_new_csv[nm][1]
        # if only old has column
        elseif nm * "_old" in names(results_compared) 
            results_clean[!,nm] = print_single.(results_compared[!,nm*"_old"], "red")
            human_readable_names[nm] = meta_csv[nm][1]
        # if only new has column
        elseif nm * "_new" in names(results_compared)
            results_clean[!,nm] = print_single.(results_compared[!,nm*"_new"], "green")
            human_readable_names[nm] = meta_new_csv[nm][1]
        # error, one of them should have the name
        else
            error("name must be in one of the dataframes")
        end
    end
    rename!(results_clean, human_readable_names)
    
    
    # output the markdown representation
    println("Benchmarking Results")
    println("All values are medians reported over 10 trials (except the 'using Pigeons' benchmark, which is run only once)")
    results_str = pretty_table(String, results_clean; backend=Val(:markdown), header_alignment=:c)

    # remove datatypes and "nothing" at the end
    to_remove = ["nothing", "<br>`Float64`", "<br>`String31`", "<br>`Int64`","<br>`String`"]
    for s in to_remove
    	results_str = replace(results_str, s => "")
    end
    # change scientific notation to be latex friendly
    results_str = replace(results_str, "e+" => "\\mathrm{e}")
    results_str = replace(results_str, "e-" => "\\mathrm{e}-")
    
    # print the result
    println(results_str)
end

main()
