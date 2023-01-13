""" 
Flag to ask to run a function to a new julia 
process. Useful e.g. to dynamically control 
the number of threads to use.  
Fields: 

$FIELDS
"""
@kwdef struct ChildProcess <: Submission  
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

    """
    If greater than one, run the code locally 
    over MPI using that many MPI processes. 
    In most cases, this is useful only for debugging purpose, 
    as multi-threading should typically perform 
    better. This could also potentially be useful if using a 
    third-party target distribution which somehow 
    does not support multi-threading. 
    """
    n_local_mpi_processes = 1

    """
    If wait is false, the process runs asynchronously.
    When wait is false, the process' I/O streams are directed to devnull.
    """
    wait = true
end 

"""
$SIGNATURES 

Run Parallel Tempering in a new process. 
See [`ChildProcess`](@ref).
"""
function pigeons(pt_arguments, new_process::ChildProcess)
    exec_folder = next_exec_folder() 
    julia_cmd = launch_cmd(
        pt_arguments,
        exec_folder,
        new_process.extra_modules,
        new_process.n_threads,
        new_process.n_local_mpi_processes == 1
    )
    if new_process.n_local_mpi_processes == 1
        run(julia_cmd, wait = new_process.wait)
    else
        mpiexec() do exe
            mpi_cmd = `$exe -n $(new_process.n_local_mpi_processes)`
            cmd = Cmd([mpi_cmd.exec; julia_cmd.exec])
            run(cmd, wait = new_process.wait)
        end
    end
    return Result{PT}(exec_folder)
end

function launch_cmd(pt_arguments, exec_folder, extra_modules, n_threads::Int, silence_mpi::Bool)
    project_folder = dirname(Base.current_project())
    julia_bin = Base.julia_cmd()
    script_path = launch_script(pt_arguments, exec_folder, extra_modules, silence_mpi)
    julia_cmd = 
        `$julia_bin 
            --project=$project_folder 
            --threads=$n_threads 
            $script_path`
    return julia_cmd
end

function launch_script(pt_arguments, exec_folder, extra_modules, silence_mpi)
    path_to_serialized_pt_arguments = "$exec_folder/.pt_argument.jls"
    path_to_serialized_immutables = "$exec_folder/immutables.jls"

    flush_immutables!()
    serialize(path_to_serialized_pt_arguments, pt_arguments)
    serialize_immutables(path_to_serialized_immutables)

    code = launch_code(
        exec_folder, 
        path_to_serialized_pt_arguments, 
        path_to_serialized_immutables,
        extra_modules,
        silence_mpi) 
    script_path = "$exec_folder/.launch_script.jl"
    write(script_path, code)
    return script_path
end

function launch_code(
        exec_folder::AbstractString, 
        path_to_serialized_pt_arguments::AbstractString, 
        path_to_serialized_immutables::AbstractString,
        extra_modules,
        silence_mpi) 
    modules = copy(extra_modules)
    push!(modules, Serialization)
    push!(modules, Pigeons)
    usings = 
        join(
            map(
                m -> "using $m", 
                unique(modules)), 
            "\n")
    # when running check_against_serial(), the 
    # child process still detect it is under MPI, so 
    # we need to force it to ignore that
    silence_code = silence_mpi ? "Pigeons.silence_mpi[] = true" : ""
    # Might be better with quote? 
    # But prototype quote-based syntax seemed more messy..
    """
    $usings

    $silence_code

    Pigeons.deserialize_immutables("$path_to_serialized_immutables")
    pt_arguments = deserialize("$path_to_serialized_pt_arguments")
    pt = PT(pt_arguments, exec_folder = "$exec_folder")
    pigeons(pt)
    """
end
