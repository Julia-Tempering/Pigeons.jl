#=
We seem to have to do this because as of Jan 2023:
1. ClusterManagers.jl supports PBS/SLURM/etc job submission but does not seem to support MPI 
2. MPIClusterManagers.jl support MPI submission but not PBS/SLURM/etc
These packages are actually unrelated despite similar names. 
In most contexts both 1 and 2 are needed for an ergonomic UI. 
=#

""" 
Flag to run on MPI.
Settings can be changed by calling [`setup_mpi`](@ref) before running.

Fields: 

$FIELDS
"""
@kwdef struct MPIProcesses <: Submission
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
    dependencies::Vector = []

    """
    MPI exec command.
    """
    mpiexec_args::Cmd = ``


end

"""
$TYPEDSIGNATURES
"""
function pigeons(pt_arguments, mpi_submission::MPIProcesses)
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
    
    # generate submission script
    # do job submission & record the submission id
    cmd = mpi_submission_cmd(exec_folder, mpi_submission, julia_cmd)
    submission_output = read(cmd, String)
    println(submission_output)
    info_folder = mkpath("$exec_folder/info")
    write("$info_folder/submission_output.txt", submission_output)
    return Result{PT}(exec_folder)
end

function mpi_submission_cmd(exec_folder, mpi_submission::MPIProcesses, julia_cmd) 
    r = rosetta()
    submission_script = mpi_submission_script(exec_folder, mpi_submission, julia_cmd)
    return `$(r.submit) $submission_script`
end

function mpi_submission_script(exec_folder, mpi_submission::MPIProcesses, julia_cmd)
    info_folder = "$exec_folder/info"
    julia_cmd_str = join(julia_cmd, " ")
    mpi_settings = load_mpi_settings()
    add_to_submission = join(mpi_settings.add_to_submission, "\n")
    r = rosetta()
    resource_str = resource_string(mpi_submission, mpi_settings.submission_system)
    exec_str = "$(cmd_to_string(mpi_settings.mpiexec)) $(cmd_to_string(mpi_submission.mpiexec_args))"
    
    code = """
    #!/bin/bash
    $resource_str
    $(r.directive) $(r.job_name)$(basename(exec_folder))
    $(r.directive) $(r.output_file)$info_folder/stdout.txt
    $(r.directive) $(r.error_file)$info_folder/stderr.txt
    $add_to_submission
    cd $(r.submit_dir)
    $(modules_string(mpi_settings))

    # don't want many processes wasting time pre-compiling, 
    export JULIA_PKG_PRECOMPILE_AUTO=0

    $exec_str $julia_cmd_str

    """
    script_path = "$exec_folder/.submission_script.sh"
    write(script_path, code)
    return script_path
end

cmd_to_string(cmd::Cmd) = "$cmd"[2:(end-1)]

"""
Specify the syntax of job submission systems such as SLURM.

Fields:

$FIELDS
"""
@kwdef struct SubmissionSyntax

    """
    The command to submit the job.
    """
    submit::Cmd

    """
    The command to delete the job.
    """
    del::Cmd

    """
    The directive to specify the job.
    """
    directive::String

    """
    The flag to specify the job name.
    """
    job_name::String

    """
    The flag to specify the output file.
    """
    output_file::String

    """
    The flag to specify the error file.
    """
    error_file::String

    """
    The flag to specify the submit directory.
    """
    submit_dir::String

    """
    The command to check the job status.
    """
    job_status::Cmd

    """
    The command to check the job status for all users.
    """
    job_stats_all::Cmd

    """
    The command to check the number of CPUs available.
    """
    ncpu_info::Cmd
end

const _rosetta = Dict{Symbol, SubmissionSyntax}(
    :pbs => SubmissionSyntax(
        submit       = `qsub`,
        del          = `qdel`,
        directive    = "#PBS",
        job_name     = "-N ",
        output_file  = "-o ",
        error_file   = "-e ",
        submit_dir   = "\$PBS_O_WORKDIR",
        job_status   = `qstat -x`,
        job_stats_all= `qstat -u`,
        ncpu_info    = `pbsnodes`
    ),
    :slurm => SubmissionSyntax(
        submit       = `sbatch`,
        del          = `scancel`,
        directive    = "#SBATCH",
        job_name     = "--job-name=",
        output_file  = "-o ",
        error_file   = "-e ",
        submit_dir   = "\$SLURM_SUBMIT_DIR",
        job_status   = `squeue --job`,
        job_stats_all= `squeue -u`,
        ncpu_info    = `sinfo -o%C`
    ),
    :lsf => SubmissionSyntax(
        submit        = `bsub`,
        del           = `bkill`,
        directive     = "#BSUB",
        job_name      = "-J ",
        output_file   = "-o ",
        error_file    = "-e ",
        submit_dir    = "\$LSB_SUBCWD",
        job_status    = `bjobs`,
        job_stats_all = `bjobs -u`,
        ncpu_info     = `bhosts`
    )
)

supported_submission_systems() = keys(_rosetta)

resource_string(m::MPIProcesses, symbol) = resource_string(m, Val(symbol))

resource_string(m::MPIProcesses, ::Val{:pbs}) =
                                    #                             +-- each chunks should request as many cpus as threads,
                                    # +-- number of "chunks"...   |                   +-- NB: if mpiprocs were set to more than 1 this would give a number of mpi processes equal to select*mpiprocs
                                    # v                           v                   v               
    "#PBS -l walltime=$(m.walltime),select=$(m.n_mpi_processes):ncpus=$(m.n_threads):mpiprocs=1:mem=$(m.memory)"

resource_string(m::MPIProcesses, ::Val{:slurm}) =
    """
    #SBATCH -t $(m.walltime)
    #SBATCH --ntasks=$(m.n_mpi_processes)
    #SBATCH --cpus-per-task=$(m.n_threads)
    #SBATCH --mem-per-cpu=$(m.memory) 
    """

function resource_string(m::MPIProcesses, ::Val{:lsf})
    @assert m.n_threads == 1 "TODO: find how to specify number of threads per node with LSF"
    """
    #BSUB -W $(m.walltime)
    #BSUB -n $(m.n_mpi_processes)
    #BSUB -M $(m.memory) 
    """
end

function rosetta() 
    mpi_settings = load_mpi_settings()
    return _rosetta[mpi_settings.submission_system] 
end