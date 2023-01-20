
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

function stdout(result)
    exec_folder = result.exec_folder 

end