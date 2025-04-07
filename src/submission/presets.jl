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
        submission_system = :slurm,
        environment_modules = ["gcc", "openmpi", "git"],
        add_to_submission = [
            "#SBATCH -A $my_user_allocation_code"
            "#SBATCH --nodes=1-10000"  # required by cluster
        ], 
        library_name = "/arc/software/spack-2024/opt/spack/linux-rocky9-skylake_avx512/gcc-9.4.0/openmpi-4.1.1-7c42tpwdhfycqa3vdhit4mspyk6a32nn/lib/libmpi"
    )

""" 
$SIGNATURES

Compute Canada clusters. 
"""
setup_mpi_compute_canada() = 
    setup_mpi(
        submission_system = :slurm,
        environment_modules = ["julia/1.11.3"],
        library_name = "/cvmfs/soft.computecanada.ca/easybuild/software/2023/x86-64-v4/Compiler/gcc12/openmpi/4.1.5/lib/libmpi"
    )