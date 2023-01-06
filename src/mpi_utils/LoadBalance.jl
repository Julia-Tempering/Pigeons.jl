"""
Split a list of indices across processes. 
These indices are denoted ``1, 2, .., N``.
They are usually some kind of task, 
for example in the context of parallel tempering, 
two kinds of tasks arise:

- in `replicas.state`, task ``i`` consists in keeping track of the state of 
    replica ``i``.
- in `replicas.chain_to_replica_global_indices`, task ``i`` consists in 
    storing which replica index corresponds to chain ``i``.

One such task index is called a `global_index`. 

LoadBalance splits the global indices among `n_processes`. LoadBalance 
is constructed so that the difference in the number of global indices 
a process is responsible of (its "load")  is at most one.

A `LoadBalance` contains:

$FIELDS

The set {1, 2, .., [`load()`](@ref)} is called a set of local indices. 
A local index indexes a slice in {1, 2, ..., `n_global_indices`}. 
Collectively over the `n_processes`, these slices form a partition of 
the global indices.

Key functions to utilize a LoadBalance struct:

- [`my_global_indices()`](@ref)
- [`find_process()`](@ref)
- [`find_local_index()`](@ref)
- [`my_load()`](@ref)

"""
struct LoadBalance
    """
    A unique index for this process. 
    We use 1-indexed,  
    i.e. hide MPI's 0-indexed ranks.
    """
    my_process_index::Int
    """
    Total number of processes involved.
    """
    n_processes::Int
    """
    The total number of global indices shared between all the processes. 
    """
    n_global_indices::Int
    """
    $TYPEDSIGNATURES
    """
    function LoadBalance(my_process_index::Int, n_processes::Int, n_global_indices::Int)
        @assert 1 ≤ my_process_index ≤ n_processes ≤ n_global_indices
        return new(my_process_index, n_processes, n_global_indices)
    end
end

"""
$TYPEDSIGNATURES
A load balance with only one process.
"""
single_process_load(n_global_indices) = LoadBalance(1, 1, n_global_indices)

"""
$TYPEDSIGNATURES
The slice of `lb.global_indices` this process is reponsible for.
"""
function my_global_indices(lb::LoadBalance)
    start = my_first_global_idx(lb)
    return start:(start+my_load(lb)-1)
end

"""
$TYPEDSIGNATURES
Find the process id (1-indexed) responsible for the given `global_idx`. 
"""
function find_process(lb::LoadBalance, global_idx::Int)::Int
    basicload = basic_load(lb)
    first_block = n_extras(lb) * (basicload + 1)
    if global_idx ≤ first_block
        return 1 + floor(Int, (global_idx - 1) / (basicload + 1))
    else
        return 1 + n_extras(lb) + floor(Int, (global_idx - first_block - 1) / basicload)
    end
end

"""
$TYPEDSIGNATURES
Find the local index corresponding to the given `global_index`. 
Assumes the given `global_index` is one of this process'. 
"""
function find_local_index(lb::LoadBalance, global_idx::Int)::Int
    first = my_first_global_idx(lb)
    len = my_load(lb)
    @assert first ≤ global_idx < first + len
    return 1 + global_idx - first
end

"""
$TYPEDSIGNATURES
Find the global index corresponding to the given `local_index`. 
"""
function find_global_index(lb::LoadBalance, local_idx::Int)::Int
    @assert 1 ≤ local_idx ≤ my_load(lb)
    return my_first_global_idx(lb) + local_idx - 1
end

"""
$TYPEDSIGNATURES
Return the number of indices (task) this process is responsible for. 
"""
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
