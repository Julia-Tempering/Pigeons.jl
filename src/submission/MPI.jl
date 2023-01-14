#=
We seem to have to do this because as of Jan 2023:
1. ClusterManagers.jl supports PBS/SLURM/etc job submission but does not seem to support MPI 
2. MPIClusterManagers.jl support MPI submission but not PBS/SLURM/etc
These packages are actually unrelated despite similar names. 
In most contexts both 1 and 2 are needed for an ergonomic UI. 
=#



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
    n_mpi_processes::Int = 1

    """
    The memory allocated to each MPI process, 8gb by default.
    """
    memory::String = "8gb"

    """
    Extra Julia `Module`s needed by the child 
    process. 
    """
    extra_modules::Vector{Module} = []
end



# TODO do-once set-up script...

function pigeons(pt_arguments, mpi_submission::MPI)
    exec_folder = next_exec_folder() 

    julia_cmd = launch_cmd(
        pt_arguments,
        exec_folder,
        mpi_submission.extra_modules,
        mpi_submission.n_threads,
        false
    )

    # TODO: if pt_arguments is a Resume, 
    # offer options to use it to populate mpi_configuration

    # generate qsub script
    # do job submission & record the submission id
    cmd = mpi_submission_cmd(exec_folder, mpi_submission, julia_cmd)
    run(cmd)
    return Result{PT}(exec_folder)
end

# todo: abstract out to other submission systems
function mpi_submission_cmd(exec_folder, mpi_submission::MPI, julia_cmd) 
    submission_script = mpi_submission_script(exec_folder, mpi_submission, julia_cmd)
    return `qsub $submission_script`
end

resource_string(m::MPI) = 
    "walltime=$(m.walltime),select=$(m.n_mpi_processes):ncpus=$(m.n_threads):mpiprocs=$(m.n_threads):mem=$(m.memory)"

function setup_mpi(; allocation_code::String)
    MPIPreferences.use_system_binary()
    @set_preferences!(
        "allocation_code" => allocation_code
    )
end

function mpi_submission_script(exec_folder, mpi_submission::MPI, julia_cmd)
    # TODO: generalize to other submission systems
    # TODO: remove a few hard-coded things
    # TODO: move some more things over from mpi-run
    # TODO: module.sh thing should be configureable too - at least written automatically
    info_folder = "$exec_folder/info"
    julia_cmd_str = join(julia_cmd, " ")
    code = """
    #!/bin/bash
    #PBS -l $(resource_string(mpi_submission))

    #PBS -A $(@load_preference("allocation_code"))
    #PBS -N $(basename(exec_folder))
    #PBS -o $info_folder/stdout.txt
    #PBS -e $info_folder/stderr.txt
    cd \$PBS_O_WORKDIR
    source ./modules.sh

    mpiexec --merge-stderr-to-stdout --output-filename $exec_folder $julia_cmd_str
    """
    script_path = "$exec_folder/.submission_script.sh"
    write(script_path, code)
    return script_path
end
