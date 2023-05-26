function mpi_test(n_processes::Int, test_file::String; options = [])
    n_processes = set_n_mpis_to_one_on_windows(n_processes)
    jl_cmd = Pigeons.julia_cmd_no_start_up()
    project_folder = dirname(Base.active_project())
    run(`$jl_cmd --project=$(project_folder) -e "using Pkg; Pkg.instantiate(); Pkg.precompile()"`)
    # handle 2 different "modes" that tests can be ran (for julia 1.0,1.1 vs. >1.1)
    resolved_test_file = 
        if isfile("$project_folder/$test_file")
            "$project_folder/$test_file" 
        else
            "$project_folder/test/$test_file"
        end
    mpiexec() do exe
        mpi_args = extra_mpi_args()
        run(`$exe $mpi_args -n $n_processes $jl_cmd -t 2 --project=$project_folder $resolved_test_file $options`)
    end
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