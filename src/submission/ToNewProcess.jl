@kwdef struct ToNewProcess <: Submission  
    n_threads::Int 
end 

function pigeons(pt_arguments, new_process::ToNewProcess)
    # run in child process, controlling the # of threads

    # useful: stuff in mpi_test

    # for now, just load Pigeons, eventually, detect & save which 
    # modules should be loaded via 
    #    https://stackoverflow.com/questions/25575406/list-of-loaded-imported-packages-in-julia
    #    see filter((x) -> typeof(eval(x)) <:  Module && x ≠ :Main, names(Main,imported=true))
    error("TODO")
end

function submission_julia_file(
        exec_folder::AbstractString, 
        path_to_serialized_pt_arguments::AbstractString, 
        path_to_serialized_immutables::AbstractString,
        modules = Set{Module}()) 
    modules = copy(modules)
    push!(modules, Serialization)
    push!(modules, Pigeons)
    return 
        """
        $(join(
            map(m -> "using $m", modules),
            "\n"
        ))

        Pigeons.deserialize_immutables(\"$path_to_serialized_immutables\")
        pt_arguments = deserialize(\"$path_to_serialized_pt_arguments\")
        pigeons()
        """
end


# MacroTools.striplines(cc)
