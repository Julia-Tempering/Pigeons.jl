""" 
$SIGNATURES 

Display the queue status for one MPI job. 
""" 
function queue_status(result::Result)
    submission_code = queue_code(result)
    r = rosetta()
    run(`$(r.job_status) $submission_code`)
    return nothing
end

queue_code(result::Result) = replace(readline("$(result.exec_folder)/info/submission_output.txt"), "Submitted batch job " => "")

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
"""
function watch(result::Result; machine = 1, last = 40, interactive = false)
    @assert machine > 0 "using 0-index convention"
    output_folder = "$(result.exec_folder)/1" # 1 is not a bug, i.e. not hardcoded machine 1

    if !isdir(output_folder) || find_rank_file(output_folder, machine) === nothing
        println("Job not yet started, try again later.")
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