"""
Assume all the MPI processes linked by this communicator 
will all call the *key operations* listed below the same number of times 
in their lifetime, at logically related occasions (e.g. a set 
number of times per iteration for algorithms running the 
same number of iterations).
We call these 'occasions' a micro-iteration.

This datastructure keeps track internally of appropriate unique 
tags to coordinate the communication between MPI processes 
without having to do any explicit synchronization. 

This struct contains:

$FIELDS

The *key operations* supported:

- [`transmit()`](@ref) and [`transmit!()`](@ref): encapsulates 
    pairwise communications in which each MPI process is holding  
    a `Vector`, the elements of which are to be permuted across the processes.
- [`all_reduce_deterministically`](@ref) and [`reduce_deterministically`](@ref), 
    to perform MPI collective reduction while maintaining the 
    Parallelism Invariance property.

"""
mutable struct Entangler
    """
    An MPI `Comm` object (or nothing if a single process is involved).
    """
    communicator::Union{Comm,Nothing}

    """
    How a set of tasks or "global indices" are distributed across processes. 
    """
    load::LoadBalance

    """
    An internal datastructure used during MPI calls.
    """
    current_received_bits::Vector{Bool} 

    """
    The current micro-iteration. Do not rely on it to 
    count logical steps as it is reset to zero after 
    `transmit_counter_bound` micor-iterations to avoid 
    underflows to negative 
    tags which cause MPI to crash. 
    """
    n_transmits::Int 

    """
    Calculated from MPI.tag_ub and n_global_indices to 
    ensure MPI tags stay valid (i.e. do not overflow into 
    negative values).
    """
    transmit_counter_bound::Int

    """
    If `parent_communicator` is `nothing`, then assume there is only 
    one machine (self) and bypass MPI.
    """
    function Entangler(n_global_indices::Int; 
            parent_communicator::Union{Comm,Nothing} = COMM_WORLD, 
            verbose::Bool = true)
        if parent_communicator === nothing
            # do everything locally (no network comm)
            comm = nothing
            transmit_counter_bound = 2^40
            my_process_index = 1
            n_processes = 1
            if verbose
                println("Entangler initialized 1 process (without MPI); $(Threads.nthreads())")
            end
        else
            init_mpi()
            comm = Comm_dup(parent_communicator)
            transmit_counter_bound = ceil(Int, tag_ub() / n_global_indices - 2)
            my_process_index = Comm_rank(comm) + 1
            n_processes = Comm_size(comm)
            if verbose && my_process_index == 1
                println("Entangler initialized $n_processes MPI processes; $(Threads.nthreads()) threads per process")
            end
        end
  
        lb = LoadBalance(my_process_index, n_processes, n_global_indices)
        received_bits = Vector{Bool}(undef, my_load(lb))
        return new(comm, lb, received_bits, 0, transmit_counter_bound)
    end
end

"""
$SIGNATURES

The same as [`transmit!()`](@ref) but instead of writing the result to an input argument, provide the result 
as a returned `Vector`. 
"""
function transmit(e::Entangler, source_data::AbstractVector{T}, to_global_indices::AbstractVector{Int})::Vector{T} where T
    result = Vector{T}(undef, length(source_data))  
    transmit!(e, source_data, to_global_indices, result)
    return result
end


"""
$SIGNATURES

Use MPI point-to-point communication to 
permute the contents of `source_data` across MPI processes, writing the permuted data into 
`write_received_data_here`. 
The permutation is specified by the load balance in the input argument `e` as well as the 
argument `to_global_indices`.

More precisely, assume the Vectors `source_data`, `to_global_indices`, and `write_received_data_here` 
are all of the length specified in `my_load(e.load)`. 

For each `i`, `source_data[i]` is sent to MPI process `p = find_process(e.load, g)`, 
where `g = to_global_indices[i]` and 
written into this `p` 's `write_received_data_here[j]`, where `j = find_local_index(e.load, g)`

See Entangler's comments regarding the requirement that all machines call transmit() the 
same number of times and at logically related intervals. 

Additionally, at each micro-iteration, we assume that 
`{to_global_indices_p : p ranges over the different processes}` forms a partition of 
`{1, ..., e.load.n_global_indices}`
If ran in single-process mode, this 'partition property' is checked; 
if ran in multi-process, opportunistic checks will be made, namely when several entries in `to_global_indices` 
lie in the same process, but systematic checks are not made for performance reasons. 

We also assume `isbitstype(T) == true`. 
"""
function transmit!(e::Entangler, source_data::AbstractVector{T}, to_global_indices::AbstractVector{Int}, write_received_data_here::Vector{T}) where T 
    myload = my_load(e.load)
    @assert myload == length(source_data) == length(write_received_data_here) == length(to_global_indices)
    @assert all(1 .≤ to_global_indices .≤ e.load.n_global_indices)
    transmit_index = next_transmit_index!(e)

    # indicators of whether each local index is to be received over MPI
    e.current_received_bits .= true 
    at_least_one_mpi = false

    requests = RequestSet() # non-blocking requests that will be waited on
    
    # send (or copy if local)
    for local_index in 1:myload
        global_index = to_global_indices[local_index]
        process_index = find_process(e.load, global_index)
        source_datum = source_data[local_index]
        
        if process_index == e.load.my_process_index
            dest_local_index = find_local_index(e.load, global_index)
            @assert e.current_received_bits[dest_local_index] "Violation of permutation property detected: two transmissions to $global_index"
            e.current_received_bits[dest_local_index] = false
            write_received_data_here[dest_local_index] = source_datum
        else
            at_least_one_mpi = true
            source_view = Ref{T}(source_datum)
            mpi_rank = process_index - 1
            # asynchronously (non-blocking) send over MPI:
            # note: we wait for the Isend request to avoid the application 
            # terminating in the last iteration without completing its request.
            request = Isend(source_view, e.communicator, dest = mpi_rank, tag = tag(e, transmit_index, global_index))
            push!(requests, request)
        end
    end

    # receive
    if at_least_one_mpi
        my_globals = my_global_indices(e.load)
        for local_index in 1:myload
            if e.current_received_bits[local_index]
                dest_view = @view write_received_data_here[local_index]
                global_index = my_globals[local_index]
                # asynchronously receive over MPI (non-blocking)
                request = Irecv!(dest_view, e.communicator, tag = tag(e, transmit_index, global_index))
                push!(requests, request)
            end
        end

        # wait that all data is received
        Waitall(requests)
    end
end

"""
$SIGNATURES

Perform a binary [reduction](https://en.wikipedia.org/wiki/MapReduce) of the 
`source_data`, using MPI when needed. 

Consider the binary tree with leaves given by the global indices specified in `e.load` and stored 
in the different MPI processes' input `source_data` vectors. 
At each node of the tree, a reduction is performed using `operation`, i.e. 
by calling `operation(left_child, right_child)`.
When, and only when a branch of the tree crosses from one MPI process to another one, 
MPI communication is used to transmit the intermediate reduction. 

At the end, for process 1, `reduce_deterministically()` will return the root of the 
binary tree, and for the other processes, `reduce_deterministically()` will return 
`nothing`. 

Note that even when the `operation` is only approximately associative (typical situation 
for floating point reductions), the output of this function is invariant to the 
number of MPI processes involved (hence the terminology 'deterministically'). 
This contrasts to direct use of MPI collective communications where the leaves are 
MPI processes and hence will give slightly different outputs given different 
numbers of MPI processes. In the context of randomized algorithms, these minor 
differences are then amplified. 

In contrast to [`transmit!()`](@ref), we do not assume `isbitstype(T) == true` and use 
serialization when messages are transmitted over MPI.
"""
function reduce_deterministically(operation, source_data::AbstractVector{T}, e::Entangler) where T
    myload = my_load(e.load)
    @assert length(source_data) == myload
    n_remaining_to_reduce = e.load.n_global_indices
    # merging will be done in this array
    work_array = copy(source_data)
    spacing = 1 # as we reduce, the spacing between remaining entries will double every iteration
    # 'global' refers to the index space shared by all machines, 'local' to the index this machines sees (indexing source_data and work_array)
    myglobals = my_global_indices(e.load)
    n_global_indices_remaining_before = first(myglobals) - 1
    # as we send off entries to the left neighbour machine, this process' first entry will shift
    my_first_remaining_local = 1
    # outer loop is over the levels of a binary tree over the global indices
    iteration = 1

    requests = RequestSet()

    while n_remaining_to_reduce > 1
        transmit_index = next_transmit_index!(e)
        current_local = my_first_remaining_local
        # on the current level of the tree, merge neighbour indices
        did_send = false

        while current_local ≤ myload 
            current_global = find_global_index(e.load, current_local)
            if isodd(n_global_indices_remaining_before) && current_local == my_first_remaining_local
                # need to send the first off to left neighbour
                dest_global_index = current_global - spacing 
                dest_process = find_process(e.load, dest_global_index)
                dest_rank = dest_process - 1
                request = isend(work_array[current_local], e.communicator; dest = dest_rank, tag = tag(e, transmit_index, iteration))
                push!(requests, request)
                current_local += spacing           
                did_send = true     
            elseif current_global + spacing ≤ e.load.n_global_indices
                # a merge into work_array[current_local]
                first_to_merge = work_array[current_local]
                # second could be local or a receive
                second_local_index = current_local + spacing 
                second_to_merge = second_local_index ≤ myload ?                    # second entry from...
                    work_array[second_local_index] :                               # ...another entry in this machine, or,
                    recv(e.communicator; tag = tag(e, transmit_index, iteration) ) # ...neighbour machine
                # merge
                work_array[current_local] = operation(first_to_merge, second_to_merge)
                current_local += 2*spacing
            else
                # the last entry of the last machine may not merge when the current level has 
                # an odd number of entries. It will be taken care of in the next level
                current_local += 2*spacing
            end  
        end
        
        if did_send 
            my_first_remaining_local += spacing
            Waitall(requests)
        end
        n_global_indices_remaining_before = ceil(Int, n_global_indices_remaining_before/2)
        spacing = spacing * 2
        n_remaining_to_reduce = ceil(Int, n_remaining_to_reduce/2)
        iteration += 1
    end

    return e.load.my_process_index == 1 ? work_array[1] : nothing
end

"""
$SIGNATURES

Same as [`reduce_deterministically()`](@ref) except that the result at the root of the 
tree is then broadcast to all machines so that the output of `all_reduce_deterministically()` 
is the root of the reduction tree for all MPI processes involved. 
"""
function all_reduce_deterministically(operation, source_data::AbstractVector{T}, e::Entangler) where T
    if e.load.my_process_index == 1
        result = reduce_deterministically(operation, source_data, e)
        if e.load.n_processes > 1
            bcast(result, e.communicator)
        end
        return result
    else
        reduce_deterministically(operation, source_data, e)
        return bcast(nothing, e.communicator)
    end
end

# Keep track internally of integer identifier for the communication micro iterations 

function tag(e::Entangler, transmit_index::Int, global_index::Int)
    # The number of pair-wise communications within a micro-iteration is at most e.load.n_global_indices,
    # so we can build tags as follows:
    return transmit_index * e.load.n_global_indices + global_index
end

# A transmit index keeps track of the micro-iteration.
# Each micro iteration contains several pairwise communications
function next_transmit_index!(e::Entangler)::Int
    # avoid "MPIError(4): MPI_ERR_TAG: invalid tag" due to overflow to negative
    if e.n_transmits > e.transmit_counter_bound
        e.n_transmits = 0
        if e.load.my_process_index == 1
            @info   """
                    To avoid MPI tag overflow, looping back to tag zero.
                    This will not cause problems unless micro-iterations 
                    across different machines can overlap by more 
                    than transmit_counter_bound micro-iterations
                    (here $(e.transmit_counter_bound) micro-iterations). For 
                    example, in non-reversible PT, that cannot happen 
                    when, e.g., 2x the number of chains (i.e. 2 x the number of 
                    global indices, here $(2 * e.load.n_global_indices)) 
                    is smaller than the transmit_counter_bound 
                    (here $(e.transmit_counter_bound)).
                    """ maxlog=1
        end
    end
    result = e.n_transmits
    e.n_transmits += 1
    return result
end
