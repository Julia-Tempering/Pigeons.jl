using Serialization
using Pigeons
Pigeons.mpi_active_ref[] = true

Pigeons.deserialize_immutables(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-03-24-17-26-45-Nlii0pif/immutables.jls")
pt_arguments = deserialize(raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-03-24-17-26-45-Nlii0pif/.pt_argument.jls")
pt = PT(pt_arguments, exec_folder = raw"/home/runner/work/Pigeons.jl/Pigeons.jl/docs/build/results/all/2023-03-24-17-26-45-Nlii0pif")
pigeons(pt)
