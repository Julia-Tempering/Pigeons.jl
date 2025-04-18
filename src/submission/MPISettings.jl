"""
Global settings needed for MPI job submission:
$FIELDS
"""
@kwdef struct MPISettings
    """
    E.g.: `:pbs`, `:slurm`, etc 

    Use `Pigeons.supported_submission_systems()` to see the list of available options.
    """
    submission_system::Symbol

    """
    Add lines to the submission scripts. 

    E.g. in Compute Canada if you are member of several accounts (see https://docs.alliancecan.ca/wiki/Running_jobs):

    `add_to_submission = ["#SBATCH --account=my_user_name"]`
    """
    add_to_submission::Vector{String} = []

    """
    "Environment modules" to load (not to be confused 
    with Julia modules). 
    Run `module avail` in the HPC login node to see 
    what is available on your HPC. 
    """
    environment_modules::Vector{String} = []

    """
    In most case, leave empty as `MPIPreferences.use_system_binary()` will 
    autodetect, but if it does not, the path to `libmpi.so` can be specified 
    manually, e.g. this is needed on compute Canada clusters (as they are not setting that 
    environment variable correctly) where it needs to be set to paths of the form
    "/cvmfs/soft.computecanada.ca/easybuild/software/2020/avx2/Compiler/intel2020/openmpi/4.0.3/lib/libmpi"
    (notice the `.so` is not included). 

    One heuristic to find this `.so` file is to modify the 
    path returned by `which mpiexec`. 
    See [`find_libmpi_from_mpiexec`](@ref) for an automated way to 
    perform this heuristic. 
    """
    library_name::Union{String, Nothing} = nothing

    """
    The mpiexec command or equivalent. For example, in other systems, 
    it needs to be set to `srun -n "\$SLURM_NTASKS"`, potentially with 
    the argument `--mpi=pmi2` in some cases. 

    Note: for the utility [`watch()`](@ref) to work correctly, the 
    output-filename should be `\$MPI_OUTPUT_PATH/mpi_out`. 

    Note: the strings `\$MPI_OUTPUT_PATH` and `\$SLURM_NTASKS` should have 
    the dollar sign escaped, see the source code for an example. 
    """
    mpiexec::String = """mpiexec --output-filename "\$MPI_OUTPUT_PATH/mpi_out" --merge-stderr-to-stdout""" # needs to be String instead of Cmd to be able to access bash variables
end

mpi_settings_folder() = "$(homedir())/.pigeons"

is_mpi_setup() = isfile("$(mpi_settings_folder())/complete")

function load_mpi_settings() 
    if !is_mpi_setup()
        error("call setup_mpi(..) first")
    end
    return deserialize("$(mpi_settings_folder())/settings.jls")
end

"""
$TYPEDSIGNATURES

Look first at the list of clusters that have "presets" available, 
by typing `Pigeons.setup_mpi_` and then tab. These are the most 
straightforward to use. 

Use `setup_mpi()` if presets are not available. See [`MPISettings`](@ref) for information on the arguments of `setup_mpi()`, 
(i.e. `args...` are passed to the constructor of [`MPISettings`](@ref)). 

Pull requests to `Pigeons/src/submission/presets.jl` are welcome 
if you would like to add a new "preset" functions of the form 
`Pigeons.setup_mpi_...()`.
"""
setup_mpi(; args...) = setup_mpi(MPISettings(; args...))

modules_string(settings::MPISettings) = 
    join(
        map(
            mod_env_str -> "module load $mod_env_str",
            settings.environment_modules
            ),
        "\n"
        )

"""
$TYPEDSIGNATURES

Execute this function once before running MPI jobs. 
This should be done on the head node of a compute cluster.
The setting are permanently saved. 
See [`MPISettings`](@ref).
"""
function setup_mpi(settings::MPISettings)
    folder = mpi_settings_folder()

    # create invisible file in home
    mkpath(folder)
    serialize("$folder/settings.jls", settings)

    # create module file
    write("$folder/modules.sh", modules_string(settings))

    # call MPIPrerences
    if settings.library_name === nothing 
        _use_system_binary()
    else
        _use_system_binary(library_names = [settings.library_name])
    end

    touch("$folder/complete") # signals success

    return nothing
end

# So that users do not have MPIPreferences listed in their direct dependencies 
# Note we are assuming Julia 1.8+, so the bug described in the "Note" of 
# https://juliaparallel.org/MPI.jl/stable/configuration/ should not apply here.
# Also makes the call more sane (avoid throwing an error on success!)
function _use_system_binary(; args...) 
    try
        MPIPreferences.use_system_binary(; args...)
    catch e 
        # we need to do this because the way MPIPreferences signal you have to restart is via 
        # error("You will need to restart Julia for the changes to take effect")
        if e.msg == "You will need to restart Julia for the changes to take effect"
            # nothing to do, MPI submissions are in separate processes so there is
            # no need to ask the restart Julia
        else
            showerror(stderr, e)
        end
    end
end

"""
A heuristic to try to locate `libmpi.so` by locating 
`mpiexec` and modifying the path appropriately. 
"""
function find_libmpi_from_mpiexec()
    mpiexec_path = Sys.which("mpiexec")
    if mpiexec_path === nothing
        error("mpiexec not found in PATH")
    end
    result = replace(mpiexec_path, "bin/mpiexec" => "lib/libmpi")
    if !isfile(result * ".so")
        error("libmpi not found at: $result")
    end
    return result
end