using Serialization
using Pigeons
Pigeons.mpi_active_ref[] = true

pt_arguments = 
    try
        Pigeons.deserialize_immutables!(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2026-07-06-16-41-11-2MDq4gza/immutables.jls")
        deserialize(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2026-07-06-16-41-11-2MDq4gza/.pt_argument.jls")
    catch e
        println("Hint: probably missing dependencies, use the dependencies argument in MPIProcesses() or ChildProcess()")
        rethrow(e)
    end

pt = PT(pt_arguments, exec_folder = raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2026-07-06-16-41-11-2MDq4gza")
pigeons(pt)
