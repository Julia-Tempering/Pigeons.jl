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
    mpi_settings = load_mpi_settings()
    @assert mpi_settings.submission_system == :pbs "Feature only supported on PBS at the moment"
    r = rosetta()
    n = 0
    for line in readlines(`$(r.ncpu_info)`)
        for item in eachsplit(line, "|")
            m = match(r"ncpus[(]f[/]t[)][=]([0-9]+)[/].*", item)
            if m !== nothing
                suffix = m.captures[1]
                n += parse(Int, suffix)
            end
        end
    end
    return n
end

""" 
$SIGNATURES

Instruct the scheduler to cancel or kill a job. 
""" 
function kill_job(result::Result) 
    r = rosetta()
    exec_folder = result.exec_folder 
    submission_code = readline("$exec_folder/info/submission_output.txt")
    run(`$(r.del) $submission_code`)
    return nothing
end

""" 
$SIGNATURES 

Print the queue status as well as the standard out 
and error streams (merged) for the given `machine`. 

Note: when using control-c on interactive = true, 
        julia tends to crash as of version 1.8. 
"""
function watch(result::Result; machine = 1, last = 40, interactive = false)
    @assert machine > 0 "using 0-index convention"
    output_folder = "$(result.exec_folder)/1" # 1 is not a bug, i.e. not hardcoded machine 1

    if !isdir(output_folder) || find_rank_file(output_folder, machine) === nothing
        println("Job not yet started, try again later.")
        println("Hint: see also queue_status(result)")
        return nothing
    end

    output_file_name = find_rank_file(output_folder, machine)
    stdout_file = "$output_folder/$output_file_name/stdout"

    cmd = `tail`
    if last !== nothing 
        cmd = `$cmd -n $last`
    end
    if interactive
        cmd = `$cmd -f`
    end

    println("Hint: showing only last $last lines; use 'last' argument to change")
    println("Watching: $stdout_file")
    run(`$cmd $stdout_file`) 
    return nothing 
end



# internal

function find_rank_file(folder, machine::Int)
    machine = machine - 1 # translate to MPI's 0-index ranks
    for file in readdir(folder)
        if match(Regex(".*rank.0*$machine"), file) !== nothing
            return file
        end
    end
    return nothing
end

# construct launch cmd and script for MPI and ChildProcess

function launch_cmd(pt_arguments, exec_folder, dependencies, n_threads::Int, on_mpi::Bool)
    script_path  = launch_script(pt_arguments, exec_folder, dependencies, on_mpi)
    jl_cmd = `$(julia_cmd_no_start_up()) --project=$(project_dir())`
    # forcing instantiate the project to make sure dependencies exist
    # also, precompile to avoid issues with coordinating access to compile cache
    run(`$jl_cmd -e "using Pkg; Pkg.instantiate(); Pkg.precompile()"`)
    return `$jl_cmd --threads=$n_threads $script_path`
end

function project_dir()
    project_file = Base.active_project() 
    # even when running outside of a user defined project, 
    # in normal circumstances Base.active_project() should 
    # yield some default global environment
    @assert !isnothing(project_file) 
    proj_dir = dirname(project_file)
    is_default_env(proj_dir) && @warn """
        Your active project is probably using a default environment. Since Pigeons
        forces precompilation of your project's packages before a distributed run,
        it is possible that some of them might fail on headless servers (see e.g.
        https://github.com/JuliaGraphics/Gtk.jl/issues/346). For this reason and
        because of the improved control they offer, we recommend using Pigeons 
        within a dedicated environment (see https://pkgdocs.julialang.org/v1/environments/). 
    """
    return proj_dir
end

# flag if user is working with one of the default named environments
is_default_env(proj_dir) = startswith(proj_dir, first(DEPOT_PATH))

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