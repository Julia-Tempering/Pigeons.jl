using Serialization
using Pigeons
Pigeons.silence_mpi[] = true

Pigeons.deserialize_immutables(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-02-10-19-09-06-CpyNIXDv/immutables.jls")
pt_arguments = deserialize(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-02-10-19-09-06-CpyNIXDv/.pt_argument.jls")

pt = PT(pt_arguments, exec_folder = raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-02-10-19-09-06-CpyNIXDv")
pigeons(pt)
