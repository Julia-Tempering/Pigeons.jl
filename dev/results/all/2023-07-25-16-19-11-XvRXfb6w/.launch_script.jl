using Serialization
using Pigeons
Pigeons.mpi_active_ref[] = true

pt_arguments = 
    try
        Pigeons.deserialize_immutables!(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-07-25-16-19-11-XvRXfb6w/immutables.jls")
        deserialize(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-07-25-16-19-11-XvRXfb6w/.pt_argument.jls")
    catch e
        println("Hint: probably missing dependencies, use the dependencies argument in MPI() or ChildProcess()")
        rethrow(e)
    end

pt = PT(pt_arguments, exec_folder = raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-07-25-16-19-11-XvRXfb6w")
pigeons(pt)
