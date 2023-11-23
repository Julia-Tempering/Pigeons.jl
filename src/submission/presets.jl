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
        add_to_submission = ["#PBS -A $my_user_allocation_code"], 
        library_name = "/arc/software/spack-2023/opt/spack/linux-centos7-skylake_avx512/gcc-9.4.0/openmpi-4.1.1-d7o6cdvp67ngi5c5wdcw2qyjyseq3l3o/lib/libmpi"
    )

""" 
$SIGNATURES

Compute Canada clusters. 
"""
setup_mpi_compute_canada() = 
    setup_mpi(
        submission_system = :slurm,
        environment_modules = ["gcc", "openmpi", "julia"],
        library_name = "/arc/software/spack-2023/opt/spack/linux-centos7-skylake_avx512/gcc-9.4.0/openmpi-4.1.1-d7o6cdvp67ngi5c5wdcw2qyjyseq3l3o/lib/libmpi"
    )