""" 
$SIGNATURES 

Display the queue status for one MPI job. 
""" 
function queue_status(result::Result)
    exec_folder = result.exec_folder 
    submission_code = queue_code(result)
    run(`qstat -x $submission_code`)
    return nothing
end

queue_code(result::Result) = readline("$exec_folder/info/submission_output.txt")

""" 
$SIGNATURES 

Display the queue status for all the user's jobs. 
"""
function queue_status()
    run(`qstat -u $(ENV["USER"])`)
    return nothing
end

function queue_ncpus_free()
    n = 0
    for line in readlines(`pbsnodes -aSj -F dsv`)
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
    exec_folder = result.exec_folder 
    submission_code = readline("$exec_folder/info/submission_output.txt")
    run(`qdel $submission_code`)
    return nothing
end

""" 
$SIGNATURES 

Print the queue status as well as the standard out 
and error streams (merged) for the given `machine`. 
"""
function watch(result::Result; machine = 1)
    @assert machine > 0 "using 0-index convention"
    queue_status(result)
    
    output_folder = "$(result.exec_folder)/1"
    print("Waiting")
    while !isfile(output_folder) || find_rank_file(output_folder, machine) === nothing
        sleep(10)
        print(".")
    end
    println()

    output_file_name = find_rank_file(output_folder, machine)
    stdout_file = "$output_folder/$output_file_name/stdout"
    
    println("Watching machine $machine stdout (note ctrl-c will not kill job, just stop monitoring):")
    run(`tail -n $last_n_lines $stdout_file`) 
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