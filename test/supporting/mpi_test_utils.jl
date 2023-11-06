function mpi_test(n_processes::Int, test_file::String; options = [])
    n_processes = set_n_mpis_to_one_on_windows(n_processes)
    jl_cmd = Pigeons.julia_cmd_no_start_up()
    project_file = Base.active_project()
    @assert !isnothing(project_file)
    project_dir = dirname(project_file)
    run(`$jl_cmd --project=$project_dir -e "using Pkg; Pkg.instantiate(); Pkg.precompile()"`)
    resolved_test_file = abspath(test_file)
    mpi_args = extra_mpi_args()
    run(`$(mpiexec()) $mpi_args -n $n_processes $jl_cmd -t 2 --project=$project_dir $resolved_test_file $options`)
end

function set_n_mpis_to_one_on_windows(default_n_mpis::Int)
    if Sys.iswindows()
        @info "MPI functionalities are not currently supported/tested on windows, see https://github.com/Julia-Tempering/Pigeons.jl/issues/34" maxlog=1
        return 1
    else
        return default_n_mpis
    end
end

function extra_mpi_args()
    MPIPreferences.abi == "OpenMPI" ? `--oversubscribe` : ``
end