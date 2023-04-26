using Serialization
using Pigeons


Pigeons.deserialize_immutables!(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-04-26-02-59-10-F2nezDFE/immutables.jls")
pt_arguments = deserialize(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-04-26-02-59-10-F2nezDFE/.pt_argument.jls")
pt = PT(pt_arguments, exec_folder = raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-04-26-02-59-10-F2nezDFE")
pigeons(pt)
