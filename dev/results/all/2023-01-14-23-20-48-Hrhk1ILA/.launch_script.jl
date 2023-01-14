using Serialization
using Pigeons
Pigeons.silence_mpi[] = true

Pigeons.deserialize_immutables("/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-01-14-23-20-48-Hrhk1ILA/immutables.jls")
pt_arguments = deserialize("/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-01-14-23-20-48-Hrhk1ILA/.pt_argument.jls")

pt = PT(pt_arguments, exec_folder = "/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-01-14-23-20-48-Hrhk1ILA")
pigeons(pt)
