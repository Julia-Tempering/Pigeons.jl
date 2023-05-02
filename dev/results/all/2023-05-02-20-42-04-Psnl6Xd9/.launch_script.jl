using Serialization
using Pigeons


Pigeons.deserialize_immutables!(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-05-02-20-42-04-Psnl6Xd9/immutables.jls")
pt_arguments = deserialize(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-05-02-20-42-04-Psnl6Xd9/.pt_argument.jls")
pt = PT(pt_arguments, exec_folder = raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-05-02-20-42-04-Psnl6Xd9")
pigeons(pt)
