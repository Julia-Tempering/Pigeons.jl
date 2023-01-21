
function queue_status(result)
    exec_folder = result.exec_folder 
    submission_code = readline("$exec_folder/info/submission_output.txt")
    run(`qstat -x $submission_code`)
    return nothing
end

function queue_status()
    run(`qstat -u $(ENV["USER"])`)
    return nothing
end

function kill_job(result) 
    exec_folder = result.exec_folder 
    submission_code = readline("$exec_folder/info/submission_output.txt")
    run(`qdel $submission_code`)
end

function watch(result; machine = 1, last_n_lines = 20)
    queue_status(result)
    output_folder = "$(result.exec_folder)/1"
    output_file_name = find_rank_file(output_folder, machine)
    stdout_file = "$output_folder/$output_file_name/stdout"
    run(`tail -n $last_n_lines $stdout_file`) # -f is nicer but crashes when 
end

function find_rank_file(folder, machine::Int)
    for file in readdir(folder)
        if match(Regex(".*rank.0*$machine"), file) !== nothing
            return file
        end
    end
    error("Standard out file not found")
end