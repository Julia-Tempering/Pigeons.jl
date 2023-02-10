using Serialization
using Pigeons
Pigeons.silence_mpi[] = true

Pigeons.deserialize_immutables(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-02-10-19-07-57-5CvHnrzk/immutables.jls")
pt_arguments = deserialize(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-02-10-19-07-57-5CvHnrzk/.pt_argument.jls")

pt = PT(pt_arguments, exec_folder = raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-02-10-19-07-57-5CvHnrzk")
pigeons(pt)
