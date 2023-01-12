""" 
Flag to ask to run a function to a new julia 
process. Useful e.g. to dynamically control 
the number of threads to use.  
Fields: 

$FIELDS
"""
@kwdef struct ToNewProcess <: Submission  
    """
    The number of threads to provide in the 
    child julia process.
    """
    n_threads::Int = Threads.nthreads()

    """
    Extra Julia `Module`s needed by the child 
    process. 
    """
    extra_modules::Vector{Module} = []
    # eventually, detect & save which 
    # modules should be loaded? E.g. could use 
    #    https://stackoverflow.com/questions/25575406/list-of-loaded-imported-packages-in-julia
    #    see filter((x) -> typeof(eval(x)) <:  Module && x ≠ :Main, names(Main,imported=true))
end 

function pigeons(pt_arguments, new_process::ToNewProcess)
    project_folder = dirname(Base.current_project())
    exec_folder = next_exec_folder() 
    julia_cmd = Base.julia_cmd()
    script_path = launch_script(pt_arguments, exec_folder, new_process.extra_modules)
    run(`$julia_cmd 
            --project=$project_folder 
            --threads $(new_process.n_threads) 
            $script_path`)
    return Result(exec_folder)
end

function launch_script(pt_arguments, exec_folder, extra_modules)
    path_to_serialized_pt_arguments = "$exec_folder/.pt_argument.jls"
    path_to_serialized_immutables = "$exec_folder/immutables.jls"

    start_serialization()
    serialize(path_to_serialized_pt_arguments, pt_arguments)
    serialize_immutables(path_to_serialized_immutables)

    code = launch_code(
        exec_folder, 
        path_to_serialized_pt_arguments, 
        path_to_serialized_immutables,
        extra_modules) 
    script_path = "$exec_folder/.launch_script.jl"
    write(script_path, code)
    return script_path
end

function launch_code(
        exec_folder::AbstractString, 
        path_to_serialized_pt_arguments::AbstractString, 
        path_to_serialized_immutables::AbstractString,
        extra_modules) 
    modules = copy(modules)
    push!(modules, Serialization)
    push!(modules, Pigeons)
    usings = 
        join(
            map(
                m -> "using $m", 
                unique(modules)), 
            "\n")
    # Might be better with quote? 
    # But prototype quote-based syntax seemed more messy..
    """
    $usings

    Pigeons.deserialize_immutables("$path_to_serialized_immutables")
    pt_arguments = deserialize("$path_to_serialized_pt_arguments")
    pt = PT(pt_arguments, exec_folder = "$exec_folder")
    pigeons(pt)
    """
end
