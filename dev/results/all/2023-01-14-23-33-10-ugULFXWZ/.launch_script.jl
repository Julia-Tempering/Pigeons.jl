using Serialization
using Pigeons


Pigeons.deserialize_immutables("/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-01-14-23-33-10-ugULFXWZ/immutables.jls")
pt_arguments = deserialize("/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-01-14-23-33-10-ugULFXWZ/.pt_argument.jls")

pt = PT(pt_arguments, exec_folder = "/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-01-14-23-33-10-ugULFXWZ")
pigeons(pt)
