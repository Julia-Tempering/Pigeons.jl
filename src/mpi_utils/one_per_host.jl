"""
For benchmarking purpose: subset the communicator so that at most one MPI process runs 
    in each machine.

Division is done so that original rank 0 is always included.

Return the new communicator or nothing if this machine is not in the subset. 
"""
function one_per_host(communicator)
    my_host_hash = hash(gethostname())
    all_host_hashes = Allgather(my_host_hash, communicator)
    my_index = Comm_rank(communicator) + 1

    # assignment strategy: if no lower rank in my machine, I am included
    include_self = !(my_host_hash in all_host_hashes[1:(my_index-1)])
    split_comm = Comm_split(communicator, include_self ? 1 : 0, 0)
    return include_self ? split_comm : nothing
end