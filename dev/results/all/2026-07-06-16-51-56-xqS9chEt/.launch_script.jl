using Serialization
using Pigeons
using DynamicPPL
Pigeons.mpi_active_ref[] = true

pt_arguments = 
    try
        Pigeons.deserialize_immutables!(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2026-07-06-16-51-56-xqS9chEt/immutables.jls")
        deserialize(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2026-07-06-16-51-56-xqS9chEt/.pt_argument.jls")
    catch e
        println("Hint: probably missing dependencies, use the dependencies argument in MPIProcesses() or ChildProcess()")
        rethrow(e)
    end

pt = PT(pt_arguments, exec_folder = raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2026-07-06-16-51-56-xqS9chEt")
pigeons(pt)
