function mpi_test(n_processes::Int, test_file::String; options = [])
    jl_cmd = Base.julia_cmd()
    project_folder = dirname(Base.current_project())
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

function extra_mpi_args()
    MPIPreferences.abi == "OpenMPI" ? `--oversubscribe` : ``
end