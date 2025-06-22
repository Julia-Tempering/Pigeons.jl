using Serialization
using Pigeons
Pigeons.mpi_active_ref[] = true

pt_arguments = 
    try
        Pigeons.deserialize_immutables!(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2025-06-22-23-25-48-J6TRFKgi/immutables.jls")
        deserialize(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2025-06-22-23-25-48-J6TRFKgi/.pt_argument.jls")
    catch e
        println("Hint: probably missing dependencies, use the dependencies argument in MPIProcesses() or ChildProcess()")
        rethrow(e)
    end

pt = PT(pt_arguments, exec_folder = raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2025-06-22-23-25-48-J6TRFKgi")
pigeons(pt)
