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

