using Serialization
using Pigeons


Pigeons.deserialize_immutables(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-03-13-19-22-55-blLlfcjJ/immutables.jls")
pt_arguments = deserialize(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-03-13-19-22-55-blLlfcjJ/.pt_argument.jls")
pt = PT(pt_arguments, exec_folder = raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-03-13-19-22-55-blLlfcjJ")
pigeons(pt)
