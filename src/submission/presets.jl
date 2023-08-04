#=
Presets for various clusters. 

Pull requests to include other systems 
are welcome. 
=#

"""
$SIGNATURES 

UBC Sockeye cluster. 
"""
setup_mpi_sockeye(my_user_allocation_code) =
    setup_mpi(
        submission_system = :pbs,
        environment_modules = ["git", "gcc", "intel-mkl", "openmpi"],
        add_to_submission = ["#PBS -A $my_user_allocation_code"]
    )

""" 
$SIGNATURES

Compute Canada clusters. 
"""
setup_mpi_compute_canada() = 
    setup_mpi(
        submission_system = :slurm,
        environment_modules = ["intel", "openmpi", "julia"],
        library_name = "/cvmfs/soft.computecanada.ca/easybuild/software/2020/avx2/Compiler/intel2020/openmpi/4.0.3/lib/libmpi"
    )