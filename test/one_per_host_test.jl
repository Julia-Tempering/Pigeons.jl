using Pigeons
using OnlineStats
using Random
using MPI

MPI.Init()
rk = MPI.Comm_rank(MPI.COMM_WORLD)
result = one_per_host(MPI.COMM_WORLD)

if result === nothing
    println("Rank $rk excluded")
else
    new_rk =  MPI.Comm_rank(result)
    println("Rank $rk included (new rank is $new_rk)")
end