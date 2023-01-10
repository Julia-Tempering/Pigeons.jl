"""
    winsorized_mean(x; α)

Compute the winsorized mean from an input `x`, which is assumed to be a vector of vectors. 
`α` denotes the percentage of observations to winsorize at the bottom and the top 
so that we use 1 - 2α observations and winsorize the rest.
"""
function winsorized_mean(x; α=0.1)
    dim_x = length(x[1])
    out = Vector{Float64}(undef, dim_x)
    n = length(x)
    n_lower = convert(Int64, floor(α*n))

    for j in 1:dim_x
        y = sort(map((i) -> x[i][j], 1:n))
        out[j] = 1/n * (n_lower * y[n_lower] + sum(y[(n_lower + 1):(n - n_lower)]) + n_lower * y[n - n_lower + 1])
    end

    return out
end


"""
    winsorized_std(x; α)

Compute the winsorized standard deviation. The parameters are the same 
as those for `winsorized_mean()`.
"""
function winsorized_std(x; α=0.1)
    dim_x = length(x[1])
    out = Vector{Float64}(undef, dim_x)
    n = length(x)
    n_lower = convert(Int64, floor(α*n))

    for j in 1:dim_x
        y = map((i) -> x[i][j], 1:n)
        y2 = y .^ 2
        y2 = sort(y2)
        y2_mean = 1/n * (n_lower * y2[n_lower] + sum(y2[(n_lower + 1):(n - n_lower)]) + n_lower * y2[n - n_lower + 1]) # winsorized estimate of E[Y[j]^2]
        out[j] = sqrt(y2_mean - winsorized_mean(y; α=α)[1]^2)
    end
    
    return out
end


"""
    lognormalizingconstant(energies, schedule)

Compute an estimate of the log normalizing constant given a vector of 
`energies` and the corresponding annealing `schedule`.
"""
function lognormalizingconstant(energies, schedule)
    n, N = size(energies)
    Δβ = schedule[2:end] .- schedule[1:end-1]
    μ = mean(energies, dims = 1)[2:end]
    sum(Δβ.*μ)
end


"""
    computeetas(ϕ, β)

Compute the `etas` matrix given `ϕ`, which is an Array(K - 1, 2) containing 
knot parameters, and `β`, a vector of `N`+1 schedules. For linear paths, 
the function returns an (N+1)x2 matrix with entries 1-β in the first column 
and β in the second column. (This function is useful for those wishing to consider
non-linear paths. However, full support is provided only for linear paths at 
the moment.) 
"""
function computeetas(ϕ, β)
    if ϕ != [0.5 0.5]
        error("ϕ must be [0.5 0.5]")
    end

    out = zeros(length(β), 2)
    for i in 1:length(β)
        out[i, 1] = 1.0 - β[i]
        out[i, 2] = β[i]
    end

    return out
end

"""
$TYPEDSIGNATURES

From one splittable random object, one can conceptualize an infinite list of splittable random objects. 
Return a slice from this infinite list.
"""
function split_slice(
        slice::UnitRange, # NB: assumes slice is contiguous, i.e. don't duck-type UnitRate
        rng)
    @assert slice[1] ≥ 1
    # todo: could be done more efficiently with a tree but low priority
    # get rid of stuff at left of slice
    n_to_burn = slice[1] - 1
    [split(rng) for i in 1:n_to_burn]
    # get the slice of random objects by splitting:
    return [split(rng) for i in slice]
end

"""
    my_fct() = @abstract()

Define an abstract function (i.e. which gives an error message if calling it 
is attempted). 
"""
macro abstract() quote error("Attempted to call an abstract function.") end end

function mpi_test(n_processes::Int, test_file::String; options = [])
    project_folder = dirname(Base.current_project())
    mpiexec() do exe
        run(`$exe -n $n_processes $(Base.julia_cmd()) --project=$project_folder $project_folder/test/$test_file $options`)
    end
end

/(s1::AbstractString, s2::AbstractString) = s1 * "/" * s2


"""
    @weighted(w, x) 

Compute w*x, but if w==0.0, do not evaluate x and just return 0.0
"""
macro weighted(w, x) 
    :($(esc(w)) == 0.0 ? 0.0 : $(esc(w)) * $(esc(x)))
end

""" 
$TYPEDSIGNATURES

Given a filename path, compute a `crc32c()` checksum 
in constant memory. 
"""
function checksum(filename::AbstractString, blocksize=16384)
    crc = zero(UInt32)
    open(filename, "r") do f
        while !eof(f)
            crc = crc32c(read(f, blocksize), crc)
        end
    end
    return crc
end

"""
$TYPEDSIGNATURES 

Heuristic to partially automate the process 
of sorting `include()`'s. 

1. Construct a graph where the vertices are the .jl files 
    under src, excluding the provided `main` file where the module is 
    defined and the includes will sit in.
2. Each file starting with a capital letter is assumed to 
    contain a struct with the same name as the file after 
    removal of the .jl suffix. Similarly, files starting 
    with `@` are assumed to contain a macro with the similarly 
    obtained name.
3. Each source file is inspected to see if the above struct and 
    macro strings are detected. This defines edges in the graph.
4. Topological sorting is attempted, if successful, print the 
    include string to copy paste to the main file, otherwise, 
    print the loops. 
"""
function sort_includes(main)
    source_files = String[]
    for (dir, sub_dir, files) in walkdir("src")
        for file in files
            if endswith(file, ".jl") && file != main
                push!(source_files, "$dir/$file") 
            end
        end
    end
    indexer = Indexer(source_files)

    graph = SimpleDiGraph(length(indexer.i2t)) 
    for file1 in source_files
        index1 = indexer.t2i[file1]
        for file2 in source_files
            index2 = indexer.t2i[file2]
            name = replace(basename(file2), ".jl" => "")
            if (name[1] == '@' || isuppercase(name[1])) && file1 != file2
                contents = read(file1, String)
                if contains(contents, name)
                    add_edge!(graph, index2, index1)
                end
            end
        end
    end

    try 
        sorted = Graphs.topological_sort_by_dfs(graph)

        for index in sorted 
            path = replace(indexer.i2t[index], "src/" => "")
            println("include(\"$path\")")
        end
    catch e
        loops = Graphs.simplecycles_hawick_james(graph)
        for loop in loops
            if length(loop) > 1
                println("loop:")
                for i in loop 
                    println("  $(indexer.i2t[i])") 
                end
            end
        end
    end
end
