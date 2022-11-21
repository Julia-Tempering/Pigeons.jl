"""
'global_index' = indices for e.g. all 'tasks', distributed globally over several machines 

Each MPI process has a process id, ONE-INDEXED [we hide MPI's 0-indexing]

LoadBalance splits the global_indices among n_processes. The different in load 
between processes is at most 1. 

The set {1, 2, .., load} is called a set of local_indices. 
A local_index indexes a slice in {1, 2, ..., n_global_indices}. 
Collectively over the n_processes, these slices form a partition of 
the global_indices.
"""
struct LoadBalance
    my_process_index::Int
    n_processes::Int
    n_global_indices::Int
    function LoadBalance(my_process_index::Int, n_processes::Int, n_global_indices::Int)
        @assert 1 ≤ my_process_index ≤ n_processes ≤ n_global_indices
        return new(my_process_index, n_processes, n_global_indices)
    end
end

function my_global_indices(lb::LoadBalance)
    start = my_first_global_idx(lb)
    return start:(start+my_load(lb)-1)
end

function find_process(lb::LoadBalance, global_idx::Int)::Int
    basicload = basic_load(lb)
    first_block = n_extras(lb) * (basicload + 1)
    if global_idx ≤ first_block
        return 1 + floor(Int, (global_idx - 1) / (basicload + 1))
    else
        return 1 + n_extras(lb) + floor(Int, (global_idx - first_block - 1) / basicload)
    end
end

function find_local_index(lb::LoadBalance, global_idx::Int)::Int
    first = my_first_global_idx(lb)
    len = my_load(lb)
    @assert first ≤ global_idx < first + len
    return 1 + global_idx - first
end

my_load(lb::LoadBalance)::Int = basic_load(lb) + (lb.my_process_index ≤ n_extras(lb) ? 1 : 0)


## Lower-level stuff:

basic_load(lb::LoadBalance)::Int = floor(Int, lb.n_global_indices / lb.n_processes)
n_extras(lb::LoadBalance)::Int = lb.n_global_indices % lb.n_processes

function my_first_global_idx(lb::LoadBalance)::Int
    n_processes_before = lb.my_process_index - 1
    n_processes_before_with_extra = min(n_processes_before, n_extras(lb))
    n_processes_before_with_basic_load = n_processes_before - n_processes_before_with_extra
    basic = basic_load(lb)
    return 1 + n_processes_before_with_basic_load * basic + n_processes_before_with_extra * (basic + 1)
end
