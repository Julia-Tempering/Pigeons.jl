@kwdef struct MPI <: Submission

end

function pigeons(pt_arguments, mpi_submission::MPI)
    # if pt_arguments is a Resume, use it to populate mpi_configuration
    # serialize pt_arguments
    # generate exec_folder
    # generate script; calls pigeons()
    # do job submission
    # return the exec_folder
    error("TODO")
end
