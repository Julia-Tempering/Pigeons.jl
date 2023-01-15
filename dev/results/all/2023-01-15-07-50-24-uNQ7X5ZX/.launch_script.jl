using Serialization
using Pigeons


Pigeons.deserialize_immutables("/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-01-15-07-50-24-uNQ7X5ZX/immutables.jls")
pt_arguments = deserialize("/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-01-15-07-50-24-uNQ7X5ZX/.pt_argument.jls")

pt = PT(pt_arguments, exec_folder = "/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-01-15-07-50-24-uNQ7X5ZX")
pigeons(pt)
