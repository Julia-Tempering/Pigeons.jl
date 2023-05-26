
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
    this way, e.g. on compute Canada to work the system not setting that 
    environment variable correctly, use 
    `/cvmfs/soft.computecanada.ca/easybuild/software/2020/avx2/Compiler/intel2020/openmpi/4.0.3/lib/libmpi`
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

Arguments are passed in the constructor of [`MPISettings`](@ref).
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

    # call bash to set things up
    julia = join(julia_cmd_no_start_up().exec, " ")
    specified_lib = 
        if settings.library_name === nothing 
            "" 
        else
            """; library_names=[raw"$(settings.library_name)"]"""
        end
    sh( """
        source $folder/modules.sh
        $julia --project -e 'using MPIPreferences; MPIPreferences.use_system_binary($specified_lib)'
        """)

    touch("$folder/complete") # signals success

    if !isempty(settings.environment_modules)
        println("""
        Important: add the line
        
            source $folder/modules.sh
        
        to your shell start-up script.
        """)
    end

    println("Please restart Julia")

    return nothing
end