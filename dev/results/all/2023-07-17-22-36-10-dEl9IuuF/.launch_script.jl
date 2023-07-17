using Serialization
using Pigeons


pt_arguments = 
    try
        Pigeons.deserialize_immutables!(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-07-17-22-36-10-dEl9IuuF/immutables.jls")
        deserialize(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-07-17-22-36-10-dEl9IuuF/.pt_argument.jls")
    catch e
        println("Hint: probably missing dependencies, use the dependencies argument in MPI() or ChildProcess()")
        rethrow(e)
    end

pt = PT(pt_arguments, exec_folder = raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-07-17-22-36-10-dEl9IuuF")
pigeons(pt)
