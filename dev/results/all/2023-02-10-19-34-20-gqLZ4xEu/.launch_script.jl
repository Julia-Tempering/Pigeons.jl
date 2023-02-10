using Serialization
using Pigeons


Pigeons.deserialize_immutables(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-02-10-19-34-20-gqLZ4xEu/immutables.jls")
pt_arguments = deserialize(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-02-10-19-34-20-gqLZ4xEu/.pt_argument.jls")

pt = PT(pt_arguments, exec_folder = raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-02-10-19-34-20-gqLZ4xEu")
pigeons(pt)
