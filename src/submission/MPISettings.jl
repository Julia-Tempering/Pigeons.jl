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

    E.g. used in UBC Sockeye for custom allocation code via 

    `add_to_submission = ["#PBS -A my_user_allocation_code"]`

    or in Compute Canada (optional if member of only one account, see https://docs.alliancecan.ca/wiki/Running_jobs):

    `add_to_submission = ["#SBATCH --account=my_user_name"]``
    """
    add_to_submission::Vector{String} = []

    """
    "Envirnonment modules" to load (not to be confused 
    with Julia modules). 
    Run `module avail` in the HPC login node to see 
    what is available on your HPC. 
    For example: `["git", "gcc", "intel-mkl", "openmpi"]` on Sockeye, 
    and `["intel", "openmpi", "julia"]` on Compute Canada
    """
    environment_modules::Vector{String} = []

    """
    In most case, leave empty as MPIPreferences.use_system_binary() will 
    autodetect, but if it does not, the path to libmpi.so can be specified 
    this way, e.g. this is needed on compute Canada clusters (as they are not setting that 
    environment variable correctly) where it needs to be set to
    "/cvmfs/soft.computecanada.ca/easybuild/software/2020/avx2/Compiler/intel2020/openmpi/4.0.3/lib/libmpi"
    (notice the .so is not included).
    """
    library_name::Union{String, Nothing} = nothing
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
$SIGNATURES

Look first at the list of clusters that have "presets" available, 
by typing `Pigeons.setup_mpi_` and then tab. These are the most 
straightforward to use. 

If presets are not available, use `setup_mpi()`. To see the 
documentation of the arguments of `setup_mpi()`, see 
[`MPISettings`](@ref)
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
$SIGNATURES

Run this function once before running MPI jobs. 
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
        if e.mgs == "You will need to restart Julia for the changes to take effect"
            # nothing to do, MPI submissions are in separate processes so there is
            # no need to ask the restart Julia
        else
            showerror(stderr, e)
        end
    end
end