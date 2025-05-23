#=
Presets for various clusters. 

Pull requests to include other systems 
are welcome. 
=#



""" 
$SIGNATURES

Compute Canada clusters. 
"""
setup_mpi_compute_canada() = 
    setup_mpi(
        submission_system = :slurm,
        environment_modules = ["julia/1.11.3"],
        library_name = find_libmpi_from_mpiexec()
    )


"""
$SIGNATURES 

UBC Sockeye cluster. 
"""
setup_mpi_sockeye(my_user_allocation_code) =
    setup_mpi(
        submission_system = :slurm,
        environment_modules = [],
        add_to_submission = [
            "#SBATCH -A $my_user_allocation_code"
            "#SBATCH --nodes=1-10000"  # required by cluster
        ], 
        library_name = "/arc/project/st-alexbou-1/software/openmpi/lib/libmpi", # Note: this will get moved to a dedicated module (WIP)
        mpiexec = """/arc/project/st-alexbou-1/software/openmpi/bin/mpiexec --output-filename "\$MPI_OUTPUT_PATH/mpi_out" --merge-stderr-to-stdout"""
    )
