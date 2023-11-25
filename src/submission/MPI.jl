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
    dependencies::Vector = []

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
    r = rosetta()
    submission_script = mpi_submission_script(exec_folder, mpi_submission, julia_cmd)
    return `$(r.submit) $submission_script`
end

function mpi_submission_script(exec_folder, mpi_submission::MPI, julia_cmd)
    # TODO: generalize to other submission systems
    # TODO: move some more things over from mpi-run
    info_folder = "$exec_folder/info"
    julia_cmd_str = join(julia_cmd, " ")
    mpi_settings = load_mpi_settings()
    add_to_submission = join(mpi_settings.add_to_submission, "\n")
    r = rosetta()
    resource_str = resource_string(mpi_submission, mpi_settings.submission_system)

    code = """
    #!/bin/bash
    $resource_str

    $add_to_submission
    $(r.directive) $(r.job_name)$(basename(exec_folder))
    $(r.directive) $(r.output_file)$info_folder/stdout.txt
    $(r.directive) $(r.error_file)$info_folder/stderr.txt
    cd $(r.submit_dir)
    $(modules_string(mpi_settings))

    # don't want many processes wasting time pre-compiling, 
    # could also be a cause for an obscure bug encountered (non-reproducible):
    #    MethodError(f=Core.Compiler.widenconst, args=(Symbol("#342"),), world=0x0000000000001342)
    export JULIA_PKG_PRECOMPILE_AUTO=0

    mpiexec $(cmd_to_string(mpi_submission.mpiexec_args)) --merge-stderr-to-stdout --output-filename $exec_folder $julia_cmd_str
    """
    script_path = "$exec_folder/.submission_script.sh"
    write(script_path, code)
    return script_path
end

cmd_to_string(cmd::Cmd) = "$cmd"[2:(end-1)]

# Internal: "rosetta stone" of submission commands
const _rosetta = (;
    queue_concept = [:submit,   :del,     :directive, :job_name,    :output_file,   :error_file,    :submit_dir,            :job_status,    :job_status_all,    :ncpu_info],

    # tested:
    pbs           = [`qsub`,    `qdel`,   "#PBS",     "-N ",        "-o ",          "-e ",          "\$PBS_O_WORKDIR",      `qstat -x`,     `qstat -u`,         `pbsnodes`],
    slurm         = [`sbatch`,  `scancel`,"#SBATCH",  "--job-name=","-o ",          "-e ",          "\$SLURM_SUBMIT_DIR",   `squeue --job`, `squeue -u`,        `sinfo -o%C`],
    
    # not yet tested:
    lsf           = [`bsub`,    `bkill`,  "#BSUB",    "-J ",        "-o ",          "-e ",          "\$LSB_SUBCWD",         `bjobs`,        `bjobs -u`,         `bhosts`],

    custom = [] # can be used by downstream libraries/users to create custom submission commands in conjuction with dispatch on Pigeons.resource_string()
)

supported_submission_systems() = filter(x -> x != :queue_concept && x != :custom, keys(_rosetta))

resource_string(m::MPI, symbol) = resource_string(m, Val(symbol))

resource_string(m::MPI, ::Val{:pbs}) =
                                    #                             +-- each chunks should request as many cpus as threads,
                                    # +-- number of "chunks"...   |                   +-- NB: if mpiprocs were set to more than 1 this would give a number of mpi processes equal to select*mpiprocs
                                    # v                           v                   v               
    "#PBS -l walltime=$(m.walltime),select=$(m.n_mpi_processes):ncpus=$(m.n_threads):mpiprocs=1:mem=$(m.memory)"

resource_string(m::MPI, ::Val{:slurm}) =
    """
    #SBATCH -t $(m.walltime)
    #SBATCH --ntasks=$(m.n_mpi_processes)
    #SBATCH --cpus-per-task=$(m.n_threads)
    #SBATCH --mem-per-cpu=$(m.memory) 
    """

function resource_string(m::MPI, ::Val{:lsf})
    @assert m.n_threads == 1 "TODO: find how to specify number of threads per node with LSF"
    """
    #BSUB -W $(m.walltime)
    #BSUB -n $(m.n_mpi_processes)
    #BSUB -M $(m.memory) 
    """
end

function rosetta() 
    mpi_settings = load_mpi_settings()
    tuple_keys = Symbol[] 
    tuple_values = Any[] 
    concepts = _rosetta.queue_concept
    selected = _rosetta[mpi_settings.submission_system] 
    len = length(selected)
    @assert len == length(concepts)
    for i in 1:len
        push!(tuple_keys, concepts[i])
        push!(tuple_values, selected[i])
    end
    return (; zip(tuple_keys, tuple_values)...)
end