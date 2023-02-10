""" 
$SIGNATURES 

Display the queue status for one MPI job. 
""" 
function queue_status(result::Result)
    submission_code = queue_code(result)
    run(`qstat -x $submission_code`)
    return nothing
end

queue_code(result::Result) = readline("$(result.exec_folder)/info/submission_output.txt")

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
function watch(result::Result; machine = 1, interactive = true)
    @assert machine > 0 "using 0-index convention"
    queue_status(result)
    output_folder = "$(result.exec_folder)/1" # 1 is not a bug, i.e. not hardcoded machine 1
    
    while !isdir(output_folder) || find_rank_file(output_folder, machine) === nothing
        if !interactive 
            return 
        end
        print("Looking for standard out file (press enter to try again, or any key and enter to stop)")
        x = readline()
        if !isempty(x)
            break
        end
        queue_status(result)
    end
    println()

    output_file_name = find_rank_file(output_folder, machine)
    stdout_file = "$output_folder/$output_file_name/stdout"
    
    println("Watching machine $machine stdout:")

    #run(`tail  $stdout_file`) 
    open(stdout_file) do io    
        while true
            data = readline(io)
            !isempty(data) && println(data)
            if isempty(data)
                if !interactive 
                    return 
                end
                sleep(1)
                print("Monitoring (press enter to try again, or any key and enter to stop)")
                x = readline()
                if !isempty(x)
                    break
                end
            end
        end
    end
    return stdout_file 
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