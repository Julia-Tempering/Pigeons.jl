#=
We seem to have to do this because as of Jan 2023:
1. ClusterManagers.jl supports PBS/SLURM/etc job submission but does not seem to support MPI 
2. MPIClusterManagers.jl support MPI submission but not PBS/SLURM/etc
These packages are actually unrelated despite similar names. 
In most contexts both 1 and 2 are needed for an ergonomic UI. 
=#

""" 
Flag to run on MPI.
Before using, you have to call once [`setup_mpi`](@ref).

Fields: 

$FIELDS
"""
@kwdef struct MPI <: Submission
    """
    The number of threads per MPI process, 1 by default.
    """
    n_threads::Int = 1

    """
    The walltime limit, 00:30:00 by default (i.e., 30 minutes).
    """
    walltime::String = "00:30:00"

    """
    The number of MPI processes, 2 by default.
    """
    n_mpi_processes::Int = 2

    """
    The memory allocated to each MPI process, 8gb by default.
    """
    memory::String = "8gb"

    """
    Julia modules (if of type `Module`) or paths to include 
    (if of type `String`) needed by the child 
    process. 
    """
    dependencies::Vector{Module} = []

    """
    Extra arguments passed to mpiexec.
    """
    mpiexec_args::Cmd = ``
end

"""
$SIGNATURES
"""
function pigeons(pt_arguments, mpi_submission::MPI)
    if !is_mpi_setup()
        error("call setup_mpi(..) first")
    end

    exec_folder = next_exec_folder() 

    julia_cmd = launch_cmd(
        pt_arguments,
        exec_folder,
        mpi_submission.dependencies,
        mpi_submission.n_threads,
        true # set mpi_active_ref flag to true
    )
    
    # generate qsub script
    # do job submission & record the submission id
    cmd = mpi_submission_cmd(exec_folder, mpi_submission, julia_cmd)
    submission_output = read(cmd, String)
    println(submission_output)
    info_folder = mkpath("$exec_folder/info")
    write("$info_folder/submission_output.txt", submission_output)
    return Result{PT}(exec_folder)
end

# todo: abstract out to other submission systems
function mpi_submission_cmd(exec_folder, mpi_submission::MPI, julia_cmd) 
    submission_script = mpi_submission_script(exec_folder, mpi_submission, julia_cmd)
    return `qsub $submission_script`
end                         #                             +-- each chunks should request as many cpus as threads,
                            # +-- number of "chunks"...   |                   +-- NB: if mpiprocs were set to more than 1 this would give a number of mpi processes equal to select*mpiprocs
resource_string(m::MPI) =   # v                           v                   v               
    "walltime=$(m.walltime),select=$(m.n_mpi_processes):ncpus=$(m.n_threads):mpiprocs=1:mem=$(m.memory)"

function mpi_submission_script(exec_folder, mpi_submission::MPI, julia_cmd)
    # TODO: generalize to other submission systems
    # TODO: move some more things over from mpi-run
    info_folder = "$exec_folder/info"
    julia_cmd_str = join(julia_cmd, " ")
    mpi_settings = load_mpi_settings()
    code = """
    #!/bin/bash
    #PBS -l $(resource_string(mpi_submission))

    #PBS -A $(mpi_settings.allocation_code)
    #PBS -N $(basename(exec_folder))
    #PBS -o $info_folder/stdout.txt
    #PBS -e $info_folder/stderr.txt
    cd \$PBS_O_WORKDIR
    $(modules_string(mpi_settings))
    mpiexec $(mpi_submission.mpiexec_args) --merge-stderr-to-stdout --output-filename $exec_folder $julia_cmd_str
    """
    script_path = "$exec_folder/.submission_script.sh"
    write(script_path, code)
    return script_path
end
