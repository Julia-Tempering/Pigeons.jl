using Serialization
using Pigeons


Pigeons.deserialize_immutables(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-02-10-19-09-41-zYLODER6/immutables.jls")
pt_arguments = deserialize(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-02-10-19-09-41-zYLODER6/.pt_argument.jls")

pt = PT(pt_arguments, exec_folder = raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-02-10-19-09-41-zYLODER6")
pigeons(pt)
