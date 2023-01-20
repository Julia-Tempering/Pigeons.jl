
"""
Global settings needed for MPI job submission:
$FIELDS
"""
@kwdef struct MPISettings
    """
    E.g., for -A in PBS submission scripts.
    """
    allocation_code::String

    """
    "Envirnonment modules" to load (not to be confused 
    with Julia modules). 
    Run `module avail` in the HPC login node to see 
    what is available on your HPC. 
    For example: `["git", "gcc", "openmpi"]`
    """
    environment_modules::Vector{String} = []
end

mpi_settings_folder() = expanduser("~/.pigeons")

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
    julia = join(Base.julia_cmd().exec, " ")
    sh( """
        source $folder/modules.sh
        $julia --project -e 'using MPIPreferences; MPIPreferences.use_system_binary()'
        """)

    touch("$folder/complete") # signals success

    if !isempty(settings.environment_modules)
        println("""
        Important: add the line
        
            source $folder/modules.sh
        
        to your shell start-up script.
        """)
    end

    return nothing
end