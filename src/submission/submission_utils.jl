""" 
$SIGNATURES 

Display the queue status for one MPI job. 
""" 
function queue_status(result::Result)
    exec_folder = result.exec_folder 
    submission_code = readline("$exec_folder/info/submission_output.txt")
    run(`qstat -x $submission_code`)
    return nothing
end

""" 
$SIGNATURES 

Display the queue status for all the user's jobs. 
"""
function queue_status()
    run(`qstat -u $(ENV["USER"])`)
    return nothing
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

Print the queue status as well as the `last_n_lines` standard out 
and error streams (merged) for the given `machine`. 
"""
function watch(result::Result; machine = 1, last_n_lines = 20)
    queue_status(result)
    output_folder = "$(result.exec_folder)/1"
    output_file_name = find_rank_file(output_folder, machine)
    stdout_file = "$output_folder/$output_file_name/stdout"
    run(`tail -n $last_n_lines $stdout_file`) # -f is nicer but crashes
    return nothing 
end

# internal

function find_rank_file(folder, machine::Int)
    @assert machine > 0 "using 0-index convention"
    machine = machine - 1 # translate to MPI's 0-index ranks
    try
        for file in readdir(folder)
            if match(Regex(".*rank.0*$machine"), file) !== nothing
                return file
            end
        end
    catch e 
        @warn e 
    end
    error("Standard out file not found (you may want to try again once the job is started)")
end