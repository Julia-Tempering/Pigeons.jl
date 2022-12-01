using Pigeons
using OnlineStats
using Random
using MPI

function test_one_host_per_host()
    MPI.Init()
    rk = MPI.Comm_rank(MPI.COMM_WORLD)
    sz = MPI.Comm_size(MPI.COMM_WORLD)
    result = one_per_host(MPI.COMM_WORLD)


    if rk == 0
        subsz = MPI.Comm_size(result)
        println("Subset of $subsz out of $sz")
    end
end

test_one_host_per_host()


