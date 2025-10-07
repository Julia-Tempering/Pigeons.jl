""" 
$SIGNATURES 

Display the queue status for one MPI job. 
""" 
function queue_status(result::Result)
    submission_code = queue_code(result)
    if submission_code === nothing 
        return nothing
    end
    r = rosetta()
    run(`$(r.job_status) $submission_code`)
    return nothing
end

function queue_code(result::Result)
    file = "$(result.exec_folder)/info/submission_output.txt"
    if !isfile(file)
        println("Submission output not found at: $file")
        println("Maybe this exec was not submitted to a queue system?")
        return nothing
    end
    return replace(readline(file), "Submitted batch job " => "")
end

""" 
$SIGNATURES 

Display the queue status for all the user's jobs. 
"""
function queue_status()
    r = rosetta()
    run(`$(r.job_status_all) $(ENV["USER"])`)
    return nothing
end

function queue_ncpus_free()
    r = rosetta()
    run(`$(r.ncpu_info)`)
    return nothing
end

""" 
$SIGNATURES

Instruct the scheduler to cancel or kill a job. 
""" 
function kill_job(result::Result) 
    r = rosetta()
    exec_folder = result.exec_folder 
    submission_code = queue_code(result)
    run(`$(r.del) $submission_code`)
    return nothing
end

""" 
$SIGNATURES 

Print the standard out 
and error streams for an MPI job. 
"""
function watch(result::Result)
    directory = "$(result.exec_folder)/info" # 1 is not a bug, i.e. not hardcoded machine 1

    if !isfile("$directory/stdout.txt") && !isfile("$directory/stderr.txt")
        println("Job not yet started, try again later.")
        println("Hint: see also queue_status(result)")
        return nothing
    end

    for file_name in ["stdout.txt", "stderr.txt"]
        if isfile("$directory/$file_name") 
            println("$file_name:")
            for line in eachline("$directory/$file_name")
                println(line)
            end
        end
    end
    
    return nothing 
end


# internal


# construct launch cmd and script for MPIProcesses and ChildProcess

function launch_cmd(pt_arguments, exec_folder, dependencies, n_threads::Int, on_mpi::Bool)
    script_path  = launch_script(pt_arguments, exec_folder, dependencies, on_mpi)
    jl_cmd = `$(julia_cmd_no_start_up()) --project=$(project_dir())`
    # forcing instantiate the project to make sure dependencies exist
    # also, precompile to avoid issues with coordinating access to compile cache
    run(`$jl_cmd -e "using Pkg; Pkg.instantiate(); Pkg.precompile()"`)
    return `$jl_cmd --threads=$n_threads --compiled-modules=$(launch_cmd_compiled_module_flag()) $script_path`
end
launch_cmd_compiled_module_flag() = VERSION >= v"1.11" ? "existing" : "no"

function project_dir()
    project_file = Base.active_project() 
    # even when running outside of a user defined project, 
    # in normal circumstances Base.active_project() should 
    # yield some default global environment
    @assert !isnothing(project_file) 
    proj_dir = dirname(project_file)
    if is_default_env() 
        @warn """
        Your active project is probably using a default environment. Since Pigeons
        forces precompilation of your project's packages before a distributed run,
        it is possible that some of them might fail on headless servers (see e.g.
        https://github.com/JuliaGraphics/Gtk.jl/issues/346). For this reason and
        because of the improved control they offer, we recommend using Pigeons 
        within a dedicated environment (see https://pkgdocs.julialang.org/v1/environments/). 
        """
    end
    return proj_dir
end

# flag if user is working with one of the default named environments
function is_default_env()
    current = abspath(Base.active_project())
    for depot in DEPOT_PATH
        envs_dir = joinpath(depot, "environments")
        isdir(envs_dir) || continue
        for entry in readdir(envs_dir)
            project_file = abspath(joinpath(envs_dir, entry, "Project.toml"))
            if current == project_file
                return true
            end
        end
    end
    return false
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
            println("Hint: probably missing dependencies, use the dependencies argument in MPIProcesses() or ChildProcess()")
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