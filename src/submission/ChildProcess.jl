""" 
Flag to run to a new julia 
process. Useful e.g. to dynamically control 
the number of threads to use.  
Fields: 

$FIELDS
"""
@kwdef struct ChildProcess <: Submission  
    """
    The number of threads to provide in the 
    child julia process, the same as the current 
    process by default.
    """
    n_threads::Int = Threads.nthreads()

    """
    Julia modules (if of type `Module`) or paths to include 
    (if of type `String`) needed by the child 
    process. 
    """
    dependencies::Vector = []
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
    n_local_mpi_processes::Int = 1

    """
    If wait is false, the process runs asynchronously.
    When wait is false, the process' I/O streams are directed to devnull.
    """
    wait::Bool = true

    """
    Extra arguments passed to mpiexec.
    """
    mpiexec_args::Cmd = ``
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
        new_process.dependencies,
        new_process.n_threads,
        new_process.n_local_mpi_processes > 1
    )
    if new_process.n_local_mpi_processes == 1
        run(julia_cmd, wait = new_process.wait)
    else
        mpiexec() do exe
            mpi_cmd = `$exe $(new_process.mpiexec_args) -n $(new_process.n_local_mpi_processes)`
            cmd     = `$mpi_cmd $julia_cmd`
            run(cmd, wait = new_process.wait)
        end
    end
    return Result{PT}(exec_folder)
end

function launch_cmd(pt_arguments, exec_folder, dependencies, n_threads::Int, on_mpi::Bool)
    script_path  = launch_script(pt_arguments, exec_folder, dependencies, on_mpi)
    jl_cmd       = Base.julia_cmd()
    project_file = Base.current_project()
    if !isnothing(project_file)
        # forcing instantiate the project to make sure dependencies exist
        # also, precompile to avoid issues with coordinating access to compile cache
        project_dir = dirname(project_file)
        jl_cmd      = `$jl_cmd --project=$project_dir`
        run(`$jl_cmd -e "using Pkg; Pkg.instantiate(); Pkg.precompile()"`)
    end
    return `$jl_cmd --threads=$n_threads $script_path`
end

function launch_script(pt_arguments, exec_folder, dependencies, on_mpi)
    path_to_serialized_pt_arguments = "$exec_folder/.pt_argument.jls"
    path_to_serialized_immutables = "$exec_folder/immutables.jls"

    flush_immutables!()
    serialize(path_to_serialized_pt_arguments, pt_arguments)
    serialize_immutables(path_to_serialized_immutables)

    # if the child spawns a child via check_against_serial, 
    # the grandchild will need to know its dependencies 
    serialize("$exec_folder/.dependencies.jls", dependencies)

    code = launch_code(
        exec_folder, 
        path_to_serialized_pt_arguments, 
        path_to_serialized_immutables,
        dependencies,
        on_mpi) 
    script_path = "$exec_folder/.launch_script.jl"
    write(script_path, code)
    return script_path
end

function launch_code(
        exec_folder::AbstractString, 
        path_to_serialized_pt_arguments::AbstractString, 
        path_to_serialized_immutables::AbstractString,
        dependencies,
        on_mpi) 
    modules = copy(dependencies)
    push!(modules, Serialization)
    push!(modules, Pigeons)
    dependency_declarations = 
        join(
            map(add_dependency, unique(modules)), 
            "\n")
    # when running check_against_serial(), the 
    # child process still detects it is under MPI, so 
    # we need to force it to ignore that
    mpi_flag = on_mpi ? "Pigeons.mpi_active_ref[] = true" : ""

    # Might be better with quote? 
    # But prototype quote-based syntax seemed more messy..
    # NB: using raw".." below to work around windows problem: backslash in paths interpreted as escape, so using suggestion in https://discourse.julialang.org/t/windows-file-path-string-slash-direction-best-way-to-copy-paste/29204
    """
    $dependency_declarations
    $mpi_flag

    Pigeons.deserialize_immutables!(raw"$path_to_serialized_immutables")
    pt_arguments = deserialize(raw"$path_to_serialized_pt_arguments")
    pt = PT(pt_arguments, exec_folder = raw"$exec_folder")
    pigeons(pt)
    """
end

add_dependency(dependency::Module) = "using $dependency"
function add_dependency(dependency::String) 
    abs_path = abspath(dependency)
    return """include(raw"$abs_path")"""
end