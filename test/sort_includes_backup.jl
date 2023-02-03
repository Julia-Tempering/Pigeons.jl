using Test
using Graphs

struct Indexer{T}
    """
    A `Vector` mapping **i**ntegers to objects **t** of type `T`.
    """
    i2t::Vector{T}

    """
    A `Dict` mapping objects **t** of type `T` to **i**ntegers.
    """
    t2i::Dict{T, Int}
end

"""
Create an `Indexer` with the given `Int` to `T` mapping.
"""
function Indexer(i2t::AbstractVector{T}) where {T}
    t2i = Dict{T, Int}()
    for i in eachindex(i2t)
        t = i2t[i]
        t2i[t] = i
    end
    return Indexer(Vector(i2t), t2i)
end




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
