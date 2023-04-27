using Serialization
using Pigeons
Pigeons.mpi_active_ref[] = true

Pigeons.deserialize_immutables!(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-04-27-02-18-01-28lqHE1z/immutables.jls")
pt_arguments = deserialize(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-04-27-02-18-01-28lqHE1z/.pt_argument.jls")
pt = PT(pt_arguments, exec_folder = raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-04-27-02-18-01-28lqHE1z")
pigeons(pt)
