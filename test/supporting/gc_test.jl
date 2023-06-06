# based on test_threads.jl in MPI.jl, added forced GC

using Test
using MPI

@info "nthreads = $(Threads.nthreads())"

MPI.Init(threadlevel=:multiple)


comm = MPI.COMM_WORLD
size = MPI.Comm_size(comm)
rank = MPI.Comm_rank(comm)

const N = 10

dst = mod(rank+1, size)
src = mod(rank-1, size)

send_arr = collect(1.0:N)
recv_arr = zeros(N)

reqs = Array{MPI.Request}(undef, 2N)

Threads.@threads for i = 1:N
    reqs[N+i] = MPI.Irecv!(@view(recv_arr[i:i]), comm; source=src, tag=i)
    reqs[i] = MPI.Isend(@view(send_arr[i:i]), comm; dest=dst, tag=i)
    if i == 1 
        GC.gc()
    end

end

MPI.Waitall(reqs)

@test recv_arr == send_arr

MPI.Finalize()
