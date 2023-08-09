""" 
Flag to run to a new julia 
process. Useful e.g. to dynamically control 
the number of threads to use or to use MPI on a 
single machine. 

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
        # # workaround used to investigate Documenter.jl bugs
        # # (Documenter.jl gobbles the stdout/stderr)
        # c2 = Cmd(julia_cmd; ignorestatus = true)
        # oc = OutputCollector(c2; verbose = false)
        # write("output.txt", merge(oc))
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
    jl_cmd       = julia_cmd_no_start_up()
    project_file = Base.active_project() 
    # even when running outside of a user defined project, 
    # in normal circumstances Base.active_project() should 
    # yield some default global environment
    # (as a corrolary, the director of the active project 
    # should not be used to find other user files)
    @assert !isnothing(project_file) 
    project_dir = dirname(project_file)
    jl_cmd  = `$jl_cmd --project=$project_dir`
    # forcing instantiate the project to make sure dependencies exist
    # also, precompile to avoid issues with coordinating access to compile cache
    run(`$jl_cmd -e "using Pkg; Pkg.instantiate(); Pkg.precompile()"`)
    return `$jl_cmd --threads=$n_threads $script_path`
end

function launch_script(pt_arguments, exec_folder, dependencies, on_mpi)
    # try to catch errors as early as possible
    preflight_checks(pt_arguments)
    
    path_to_serialized_pt_arguments = "$exec_folder/.pt_argument.jls"
    path_to_serialized_immutables = "$exec_folder/immutables.jls"

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
    modules = []
    push!(modules, Serialization)
    push!(modules, Pigeons)
    append!(modules, dependencies)
    dependency_declarations = 
        join(
            map(add_dependency, unique(modules)), 
            "\n")
    # when running check_against_serial(), the 
    # child process still detects it is under MPI, so 
    # we need to force it to ignore that
    mpi_flag = on_mpi ? "Pigeons.mpi_active_ref[] = true" : ""

    # NB: using raw".." below to work around windows problem: backslash in paths interpreted as escape, so using suggestion in https://discourse.julialang.org/t/windows-file-path-string-slash-direction-best-way-to-copy-paste/29204
    """
    $dependency_declarations
    $mpi_flag

    pt_arguments = 
        try
            Pigeons.deserialize_immutables!(raw"$path_to_serialized_immutables")
            deserialize(raw"$path_to_serialized_pt_arguments")
        catch e
            println("Hint: probably missing dependencies, use the dependencies argument in MPI() or ChildProcess()")
            rethrow(e)
        end

    pt = PT(pt_arguments, exec_folder = raw"$exec_folder")
    pigeons(pt)
    """
end

add_dependency(dependency::Module) = "using $dependency"
function add_dependency(dependency::String) 
    abs_path = abspath(dependency)
    return """include(raw"$abs_path")"""
end