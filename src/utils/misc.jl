value_with_default(stats::GroupBy, key, default) =
    haskey(stats.value, key) ? value(stats[key]) : default

# somehow Julia doesn't have that? (double check)
inf(object::T) where {T<:Number} = inf(T)
inf(T::Type{Float16}) = Inf16 
inf(T::Type{Float32}) = Inf32 
inf(T::Type{Float64}) = Inf

sqr_norm(x) = sum(abs2, x)

julia_cmd_no_start_up() = `$(Base.julia_cmd()) --startup-file=no --banner=no`


"""
$SIGNATURES

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
$SIGNATURES 

Heuristic to automate the process 
of sorting `include()`'s.
 
Topological sorting of the source files under src 
(excluding `main`) is attempted, if successful, print the 
include string to copy and paste to the main file, otherwise, 
print the detected loops. 

Internally, this function will:

1. Construct a graph where the vertices are the .jl files 
    under src, excluding the provided `main` file (i.e. where the module is 
    defined and the includes will sit in).
2. Each file starting with a capital letter is assumed to 
    contain a struct with the same name as the file after 
    removal of the .jl suffix. Similarly, files starting 
    with `@` are assumed to contain a macro with the similarly 
    obtained name.
3. Each source file is inspected to see if the above struct and 
    macro strings are detected. This defines edges in the graph.
    (known limitation: this includes spurious edges when e.g. 
    the string occurs in a comment).

"""
function sort_includes!(main)
    sorted = sort_includes(main)
    if isfile("src/includes.jl")
        mv("src/includes.jl", "src/.includes_bu.jl", force = true)
        println("Created back-up of src/includes.jl as src/.includes_bu.jl")
    end
    includes = map(x -> "include(\"$x\")", sorted)
    write( "src/includes.jl",
        """
        # include()'s generated using: sort_includes!(\"main\")
        $(join(includes, "\n"))
        """
    )
    return nothing
end

function sort_includes(main)
    source_files = String[]
    for (dir, sub_dir, files) in walkdir("src")
        for file in files
            if endswith(file, ".jl") && 
                    file != main && # ignore entrypoint
                    file != "includes.jl" &&
                    !startswith(file, ".") # ignore backup
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
        output = [] 
        for index in sorted 
            path = replace(indexer.i2t[index], "src/" => "")
            push!(output, path)
        end
        return output
    catch e
        loops = Graphs.simplecycles_hawick_james(graph)
        msg = "loops detected:\n"
        for loop in loops
            if length(loop) > 1
                msg *= "loop:\n"
                for i in loop 
                    msg *= "  $(indexer.i2t[i])\n" 
                end
            end
        end
        error(msg)
    end
end
