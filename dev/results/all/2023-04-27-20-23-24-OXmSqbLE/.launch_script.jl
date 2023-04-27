using Serialization
using Pigeons


Pigeons.deserialize_immutables!(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-04-27-20-23-24-OXmSqbLE/immutables.jls")
pt_arguments = deserialize(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-04-27-20-23-24-OXmSqbLE/.pt_argument.jls")
pt = PT(pt_arguments, exec_folder = raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-04-27-20-23-24-OXmSqbLE")
pigeons(pt)
