using Serialization
using Pigeons


pt_arguments = 
    try
        Pigeons.deserialize_immutables!(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2026-02-04-10-04-02-rtk7LddN/immutables.jls")
        deserialize(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2026-02-04-10-04-02-rtk7LddN/.pt_argument.jls")
    catch e
        println("Hint: probably missing dependencies, use the dependencies argument in MPIProcesses() or ChildProcess()")
        rethrow(e)
    end

pt = PT(pt_arguments, exec_folder = raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2026-02-04-10-04-02-rtk7LddN")
pigeons(pt)
