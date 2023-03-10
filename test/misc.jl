function mpi_test(n_processes::Int, test_file::String; options = [])
    project_folder = dirname(Base.current_project())
    # handle 2 different "modes" that tests can be ran (for julia 1.0,1.1 vs. >1.1)
    resolved_test_file = 
        if isfile("$project_folder/$test_file")
            "$project_folder/$test_file" 
        else
            "$project_folder/test/$test_file"
        end
    mpiexec() do exe
        mpi_args = Pigeons.extra_mpi_args()
        run(`$exe $mpi_args -n $n_processes $(Base.julia_cmd()) --project=$project_folder $resolved_test_file $options`)
    end
end