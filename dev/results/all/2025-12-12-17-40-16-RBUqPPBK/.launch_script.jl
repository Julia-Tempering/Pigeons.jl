using Serialization
using Pigeons
include(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/examples/ising.jl")
include(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/examples/lazy-ising.jl")
Pigeons.mpi_active_ref[] = true

pt_arguments = 
    try
        Pigeons.deserialize_immutables!(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2025-12-12-17-40-16-RBUqPPBK/immutables.jls")
        deserialize(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2025-12-12-17-40-16-RBUqPPBK/.pt_argument.jls")
    catch e
        println("Hint: probably missing dependencies, use the dependencies argument in MPIProcesses() or ChildProcess()")
        rethrow(e)
    end

pt = PT(pt_arguments, exec_folder = raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2025-12-12-17-40-16-RBUqPPBK")
pigeons(pt)
